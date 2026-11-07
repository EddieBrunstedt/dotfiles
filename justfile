set ignore-comments := true

# List available recipes
default:
    @just --list

# Symlink dotfiles into $HOME, then fetch the yazi plugins pinned in package.toml
install:
    stow .
    ya pkg install

# Re-symlink, cleaning up stale links
restow:
    stow --restow .

# Remove all symlinks from $HOME
uninstall:
    stow --delete .

# Install root-owned files: uwsm session entry, no-sleep, power key (once per machine)
install-session:
    sudo install -Dm644 \
        system/usr/share/wayland-sessions/mango-uwsm.desktop \
        /usr/share/wayland-sessions/mango-uwsm.desktop
    sudo install -Dm644 \
        system/etc/systemd/sleep.conf.d/no-sleep.conf \
        /etc/systemd/sleep.conf.d/no-sleep.conf
    sudo install -Dm644 \
        system/etc/systemd/logind.conf.d/power-key.conf \
        /etc/systemd/logind.conf.d/power-key.conf
    # Reload, not restart: restarting logind can end the session.
    sudo systemctl kill -s HUP systemd-logind

# Enable user systemd services (once per machine, after `install`)
enable-services:
    systemctl --user daemon-reload
    systemctl --user enable \
        protonmail-bridge.service \
        keymode-hint.service \
        swayidle.service \
        vault-cleanup.service \
        wallpaper.service \
        waybar.service
    systemctl --user add-wants graphical-session.target soteria.service
    # ydotool is voxtype's typing backend; voxtype itself is started from waybar.
    # /dev/uinput is only writable once logged in (uaccess), so not at boot.
    systemctl --user disable ydotool.service
    systemctl --user add-wants graphical-session.target ydotool.service
    # default.target units only start at boot with lingering on.
    loginctl enable-linger $USER

# List broken symlinks pointing into the dotfiles repo
clean-orphans:
    @find $HOME -xdev \
        -path "$HOME/.local/share/Trash" -prune -o \
        -type d ! -readable -prune -o \
        -xtype l -lname '*dotfiles*' -print

# Delete the broken symlinks listed by `clean-orphans`
# (rm rather than -delete, which implies -depth and disables -prune)
clean-orphans-apply:
    @find $HOME -xdev \
        -path "$HOME/.local/share/Trash" -prune -o \
        -type d ! -readable -prune -o \
        -xtype l -lname '*dotfiles*' -print -exec rm -- {} +
