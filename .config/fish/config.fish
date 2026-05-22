# Load secret environment variables if available.
set -l secret_env_loader "$HOME/.local/bin/load-secret-env"
if test -x "$secret_env_loader"
    for line in ($secret_env_loader | string split0)
        set -l pair (string split -m1 = -- $line)
        test (count $pair) -eq 2; and set -gx $pair[1] $pair[2]
    end
end

stty -ixon 2>/dev/null

# Zig toolchain managed by zvm
fish_add_path -g ~/.local/share/zvm/bin

set -g fish_greeting
set -g fish_key_bindings fish_vi_key_bindings

bind ctrl-y accept-autosuggestion
bind -M insert ctrl-y accept-autosuggestion

alias l="eza -l --group-directories-first --time-style=iso"
alias ls="eza --group-directories-first --time-style=iso"
alias lsa="eza -a --group-directories-first --time-style=iso"
alias ll="l"
alias la="eza -la --group-directories-first --time-style=iso"
alias lt="eza --tree --group-directories-first --time-style=iso"
alias lta="eza -a --tree --group-directories-first --time-style=iso"
alias lll="eza -lgh --group-directories-first --git --time-style=long-iso"
alias llla="eza -lgha --group-directories-first --git --time-style=long-iso"
alias llt="eza --long --tree --group-directories-first --time-style=iso"
alias llta="eza -a --long --tree --group-directories-first --time-style=iso"

alias vim="nvim"
alias lg="lazygit"
alias man="batman"
alias bc="bc -l"
alias pi="~/code/pi-mono/packages/coding-agent/binaries/linux-x64/pi"

alias ka="killall"
alias tkill="tmux kill-server"
alias clip='xclip -selection clipboard'

alias bat="bat --style=header --style=auto --theme base16"

alias analyze_disk_usage="duf"

function yt
    if test (count $argv) -lt 2
        echo "Usage: yt <url> <cookie_file>"
        echo "Error: both URL and cookie file path are required."
        return 1
    end

    set -l url $argv[1]
    set -l cookie_file $argv[2]
    set -l output "%(upload_date)s-%(uploader)s-%(title)s-[%(id)s].%(ext)s"

    yt-dlp --cookies "$cookie_file" --restrict-filenames -f "bv*+ba/b" --merge-output-format mkv -o "$output" "$url"
end

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# fzf.fish: hidden files in pickers, eza-tree previews for directories
set -g fzf_fd_opts --hidden --follow --exclude=.git
set -g fzf_preview_dir_cmd eza --tree --color=always --icons=auto --group-directories-first

# Defaults for direct `fzf` invocations
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude=.git'
set -gx FZF_DEFAULT_OPTS '--height=50% --layout=reverse --border --cycle --info=inline'

# Point ssh at the systemd-managed agent socket
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

if status is-interactive
    # Rebind fzf.fish: Ctrl-T for file/dir picker; skip history binding so atuin keeps Ctrl-R.
    # Must run before atuin init so atuin's ctrl-r binding wins.
    fzf_configure_bindings --directory=ctrl-t --history=

    starship init fish | source
    zoxide init fish | source
    navi widget fish | source
    atuin init fish | source
    direnv hook fish | source

    # Autostart tmux
    if not set -q TMUX
        # Check if tmux is installed
        command -v tmux &>/dev/null
        and test -z "$TMUX"
        and exec tmux new-session -A -s main
    end
end
