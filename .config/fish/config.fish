source ~/.secrets/env

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
alias timr="timr -n on"
alias bc="bc -l"

alias ka="killall"
alias tkill="tmux kill-server"

alias bat="bat --style=header --style=auto --theme base16"

alias hledger="hledger -s"
alias eco="hledger bs -X DKK -c '1,000.00 DKK'"

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

    yt-dlp --cookies "$cookie_file" --restrict-filenames -o "$output" "$url"
end

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# Make fzf show hidden files/directories
set -g fzf_fd_opts --hidden --follow --exclude=.git

# Start ssh-agent if not already running
if not pgrep -x ssh-agent > /dev/null
    eval (ssh-agent -c)
    echo $SSH_AGENT_PID > ~/.ssh-agent-pid
else
    # Use existing ssh-agent
    if test -f ~/.ssh-agent-pid
        set -x SSH_AGENT_PID (cat ~/.ssh-agent-pid)
        set -x SSH_AUTH_SOCK (find /tmp -name "agent.*" -user (whoami) 2>/dev/null | head -1)
    end
end

if status is-interactive
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
