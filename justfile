# List available recipes
default:
    @just --list

# Symlink dotfiles into $HOME
install:
    stow .

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
        dwmblocksrs.service \
        sxhkd.service \
        unclutter.service \
        nitrogen-restore.service \
        protonmail-bridge.service
