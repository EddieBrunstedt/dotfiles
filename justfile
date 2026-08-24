# List available recipes
default:
    @just --list

# Symlink dotfiles into $HOME
install:
    stow .

# Install the root-owned uwsm session entry (once per machine)
install-session:
    # Root-owned, so stow cannot place it. Without this the greeter offers only
    # the packaged `Mango` session, which runs the compositor bare: no uwsm, so
    # no environment preload, no graphical-session target, no slice layout.
    sudo install -Dm644 \
        system/usr/share/wayland-sessions/mango-uwsm.desktop \
        /usr/share/wayland-sessions/mango-uwsm.desktop

# Re-symlink, cleaning up stale links
restow:
    stow --restow .

# Remove all symlinks from $HOME
uninstall:
    stow --delete .

# List broken symlinks pointing into the dotfiles repo
clean-orphans:
    @find $HOME -xdev \
        -path "$HOME/.local/share/Trash" -prune -o \
        -xtype l -lname '*dotfiles*' -print

# Delete the broken symlinks listed by `clean-orphans`
clean-orphans-apply:
    @find $HOME -xdev \
        -xtype l -lname '*dotfiles*' \
        -not -path "$HOME/.local/share/Trash/*" \
        -print -delete

# Enable user systemd services (run once after `install` on a fresh machine)
enable-services:
    systemctl --user daemon-reload
    systemctl --user enable \
        desktop-watch.service \
        protonmail-bridge.service \
        vault-cleanup.service \
        wallpaper.service \
        waybar.service
    # soteria's packaged unit installs to default.target; wire it to the
    # graphical session instead
    systemctl --user add-wants graphical-session.target soteria.service
    # vault-cleanup and the forgejo runner are wanted by default.target, which
    # only runs at boot with lingering on
    loginctl enable-linger $USER

# Enable the Forgejo Actions runner (this machine only; needs a runner token)
enable-forgejo:
    #!/usr/bin/env bash
    set -euo pipefail
    token=~/.config/forgejo-runner/runner-token
    if [[ ! -s $token ]]; then
        echo "No runner token at $token." >&2
        echo "Register the runner first: forgejo-runner register --instance https://codeberg.org/" >&2
        exit 1
    fi
    systemctl --user enable --now forgejo-runner.service
