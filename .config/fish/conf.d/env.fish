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

# Load secret environment variables if available.
set -l secret_env_loader "$HOME/.local/bin/load-secret-env"
if test -x "$secret_env_loader"
    for line in ($secret_env_loader | string split0)
        set -l pair (string split -m1 = -- $line)
        test (count $pair) -eq 2; and set -gx $pair[1] $pair[2]
    end
end

# Zig toolchain managed by zvm
fish_add_path -g ~/.local/share/zvm/bin

# pnpm
fish_add_path -g ~/.local/share/pnpm/bin

# npm global installs (prefix = ~/.npm-global)
fish_add_path -g ~/.npm-global/bin

# Disable fish greeting
set -g fish_greeting ""

# fzf.fish: hidden files in pickers, eza-tree previews for directories
set -g fzf_fd_opts --hidden --follow --exclude=.git
set -g fzf_preview_dir_cmd eza --tree --color=always --icons=auto --group-directories-first

# Defaults for direct `fzf` invocations
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude=.git'
set -gx FZF_DEFAULT_OPTS '--height=50% --layout=reverse --border --cycle --info=inline'

# Point ssh at the systemd-managed agent socket
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

# Batdiff uses delta
set -gx BATDIFF_USE_DELTA true

# Disable memory in Claude Code
set -gx CLAUDE_CODE_DISABLE_AUTO_MEMORY 1

# Use fullscreen mode in Claude Code
set -gx CLAUDE_CODE_NO_FLICKER 1
