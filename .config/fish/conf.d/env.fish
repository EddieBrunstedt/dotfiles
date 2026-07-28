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

# Secrets are NOT loaded here: conf.d/ is sourced for non-interactive fish too.
# They come from the login keyring in config.fish's interactive block instead.

# $PATH. These mirror ~/.profile on purpose rather than duplicating it by
# accident: under uwsm, fish inherits a fully-built PATH from the systemd
# activation environment and fish_add_path is a no-op (it skips entries already
# present). But fish never sources ~/.profile, so a plain TTY login with fish as
# the login shell would otherwise start with no ~/.local/bin — and config.fish
# calls `secret-env` from there. Keep this list in sync with ~/.profile.
fish_add_path -g ~/.local/bin
fish_add_path -g ~/.local/bin/statusbar
fish_add_path -g ~/.cargo/bin
fish_add_path -g ~/.local/share/zvm/bin
# pnpm installs global binaries directly into $PNPM_HOME, not a bin/ below it.
fish_add_path -g ~/.local/share/pnpm
fish_add_path -g ~/.npm-global/bin

# Disable fish greeting
set -g fish_greeting ""

# fzf.fish: hidden files in pickers, eza-tree previews for directories
set -g fzf_fd_opts --hidden --follow --exclude=.git
set -g fzf_preview_dir_cmd eza --tree --color=always --icons=auto --group-directories-first

# Defaults for direct `fzf` invocations
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude=.git'
set -gx FZF_DEFAULT_OPTS '--height=50% --layout=reverse --border --cycle --info=inline'

# SSH_AUTH_SOCK now comes from ~/.config/environment.d/10-defaults.conf, so GUI
# git clients get it too. Set here as well only for a TTY login without uwsm,
# where nothing has read environment.d.
set -q SSH_AUTH_SOCK; or set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

# Batdiff uses delta
set -gx BATDIFF_USE_DELTA true

# Disable memory in Claude Code
set -gx CLAUDE_CODE_DISABLE_AUTO_MEMORY 1

# Use fullscreen mode in Claude Code
set -gx CLAUDE_CODE_NO_FLICKER 1
