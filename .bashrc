#!/bin/bash

#Disable ctrl-s and ctrl-q.
[[ $- == *i* ]] && stty -ixon

#Allows you to cd into directory merely by typing the directory name.
shopt -s autocd

# Secrets come from the login keyring, not a file on disk. Guarded because
# ~/.local/bin is only on PATH once ~/.profile has run, and bash sources this
# file directly in non-login interactive shells too.
command -v secret-env >/dev/null 2>&1 && eval "$(secret-env export --sh)"

#Infinite history
HISTSIZE= HISTFILESIZE= # Infinite history.

#PS1 colors
export PS1='\[\033[1;33m\]\u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]'

#Load aliases
[ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"

#Force tmux to assume that the terminal support 256 colors
alias tmux="tmux -2"
