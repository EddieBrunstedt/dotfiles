# Environment, $PATH, and tool-config variables.

# Store history on RAM only. Fish has no var to relocate its history file, so we
# symlink it into $XDG_RUNTIME_DIR (tmpfs). The link lives in the persistent
# data dir; the contents live on RAM and are wiped on logout.
set -l fish_hist ~/.local/share/fish/fish_history
set -l hist_target "$XDG_RUNTIME_DIR/fish_history"
if test -n "$XDG_RUNTIME_DIR"; and test "$(readlink $fish_hist)" != "$hist_target"
    rm -f "$fish_hist"
    ln -s "$hist_target" "$fish_hist"
end

# Secrets are deliberately not loaded into any shell. They live encrypted in
# ~/.secret/ and are fetched per-process by `sec NAME` or the per-tool shims in
# ~/.local/bin/shims. See ~/.secret/README.md.

# $PATH is assembled in ~/.profile and nowhere else. Under uwsm fish inherits
# the finished product and this is a no-op, but fish never sources ~/.profile,
# so a TTY login with fish as the login shell would start without ~/.local/bin.
# Rather than restate the list and let the two drift, ask a POSIX login shell
# for the PATH it builds: /bin/sh is bash, and bash invoked as `sh` reads
# ~/.profile (POSIX mode ignores ~/.bash_profile). This also picks up
# /etc/profile.d — cuda, jvm, rustup, perl.
if not contains $HOME/.local/bin/shims $PATH
    set -gx PATH (sh -lc 'printf %s "$PATH"' | string split :)
end

# Disable fish greeting
set -g fish_greeting ""

# fzf.fish: hidden files in pickers, eza-tree previews for directories. Fish
# variables read by the plugin, not environment — FZF_DEFAULT_COMMAND/OPTS are
# environment and live in ~/.config/environment.d/10-defaults.conf.
set -g fzf_fd_opts --hidden --follow --exclude=.git
set -g fzf_preview_dir_cmd eza --tree --color=always --icons=auto --group-directories-first

# SSH_AUTH_SOCK comes from ~/.config/environment.d/10-defaults.conf. Repeated
# here only for a TTY login without uwsm, where nothing has read environment.d.
set -q SSH_AUTH_SOCK; or set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
