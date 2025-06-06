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

alias ka="killall"
alias tkill="tmux kill-server"

alias bat="bat --style=header --style=auto --theme base16"

alias hledger="hledger -s"
alias eco="hledger bs -X DKK -c '1,000.00 DKK'"

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
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
