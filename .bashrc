#!/bin/bash

#Disable ctrl-s and ctrl-q.
[[ $- == *i* ]] && stty -ixon

#Allows you to cd into directory merely by typing the directory name.
shopt -s autocd

# Secrets are not in the environment; fetch on demand with `sec NAME`.
# See ~/.secret/README.md

#Infinite history
HISTSIZE= HISTFILESIZE= # Infinite history.

#PS1 colors
export PS1='\[\033[1;33m\]\u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]'

#Force tmux to assume that the terminal support 256 colors
alias tmux="tmux -2"
