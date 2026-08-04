#!/bin/bash
# Interactive bash. Rarely used — fish is the login shell — so this stays small.
# vi bindings come from ~/.inputrc (readline), not from here.

# Free Ctrl-S / Ctrl-Q by disabling XON/XOFF flow control.
[[ $- == *i* ]] && stty -ixon

# `cd` into a directory by typing its name alone.
shopt -s autocd

# Unlimited history, in memory and on disk.
HISTSIZE= HISTFILESIZE=

# Secrets are not in the environment; fetch on demand with `sec NAME`.
# See ~/.secret/README.md

export PS1='\[\033[1;33m\]\u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]'

# Force 256-color mode; the terminal's TERM is not always trusted by tmux.
alias tmux="tmux -2"
