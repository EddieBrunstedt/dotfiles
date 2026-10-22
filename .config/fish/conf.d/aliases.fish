abbr -a vim nvim
abbr -a lg lazygit
abbr -a ka 'killall'
abbr -a clip 'wl-copy'
abbr -a j 'just'
abbr -a dc 'cd ~/desktop && claude'

alias disk_usage="duf"

# ── eza ──
set -l eza_global --group-directories-first --icons=auto
set -l eza_time_format --time-style=long-iso

alias l="eza $eza_global"
alias la="eza $eza_global -a"
alias ls="eza $eza_global -lg --smart-group --no-time"
alias lsa="eza $eza_global -lga --smart-group --no-time"
alias lsl="eza $eza_global -lgh --smart-group --git $eza_time_format"
alias lsla="eza $eza_global -lgha --smart-group --git $eza_time_format"
alias lsize="eza $eza_global -lgh --total-size --color-scale=size --sort=size --reverse $eza_time_format"
# Git status of every repo in the current folder
alias lrepo="eza $eza_global -lg --git-repos --smart-group $eza_time_format"
