set -g fish_greeting ""

# History on tmpfs: fish can't relocate it, so symlink it into $XDG_RUNTIME_DIR.
set -l fish_hist ~/.local/share/fish/fish_history
set -l hist_target "$XDG_RUNTIME_DIR/fish_history"
if test -n "$XDG_RUNTIME_DIR"; and test "$(readlink $fish_hist)" != "$hist_target"
    rm -f "$fish_hist"
    ln -s "$hist_target" "$fish_hist"
end

# PATH lives in ~/.profile. Under uwsm it is inherited; on a TTY login ask sh for it.
if not contains $HOME/.local/bin/shims $PATH
    set -gx PATH (sh -lc 'printf %s "$PATH"' | string split :)
end

# Fallbacks for a TTY login, where environment.d hasn't been read.
set -q SSH_AUTH_SOCK; or set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
set -q SOPS_AGE_KEY_CMD; or set -gx SOPS_AGE_KEY_CMD "secret-tool lookup xdg:schema dev.dotfiles.age name sops"

# fzf.fish plugin settings (FZF_DEFAULT_* are in environment.d).
set -g fzf_fd_opts --hidden --follow --exclude=.git
set -g fzf_preview_dir_cmd eza --tree --color=always --icons=auto --group-directories-first
