source ~/.secrets/env

set -g fish_greeting
set -g fish_key_bindings fish_vi_key_bindings

bind ctrl-y accept-autosuggestion
bind -M insert ctrl-y accept-autosuggestion

alias l="eza -l --group-directories-first --time-style=iso"
alias ls="eza --group-directories-first"
alias lll="eza -lgh --group-directories-first --git --time-style=long-iso"
alias la="eza -la --group-directories-first"
alias lt="eza --long --tree --group-directories-first"
alias lta="eza -a --long --tree --group-directories-first"

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

    export ZELLIJ_AUTO_ATTACH=true
    export ZELLIJ_AUTO_EXIT=true
    eval (zellij setup --generate-auto-start fish | string collect)
end
