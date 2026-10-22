#!/bin/bash
# Rarely used; fish is the login shell. vi mode comes from ~/.inputrc.

# .bash_profile sources this for non-interactive login shells too.
[[ $- == *i* ]] || return

stty -ixon
shopt -s autocd

# History in memory only, like fish.
HISTSIZE=10000
HISTFILESIZE=0
unset HISTFILE

PS1='\[\033[1;33m\]\u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]'
