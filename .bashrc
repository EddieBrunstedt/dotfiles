#!/bin/bash
# Interactive bash. Rarely used — fish is the login shell — so this stays small.
# vi bindings come from ~/.inputrc (readline), not from here.

# .bash_profile sources this file for every login shell, including
# non-interactive ones like `bash -lc`. Nothing below belongs in those: autocd
# changes how a bare directory token is parsed, and the rest needs a tty.
[[ $- == *i* ]] || return

# Free Ctrl-S / Ctrl-Q by disabling XON/XOFF flow control.
stty -ixon

# `cd` into a directory by typing its name alone.
shopt -s autocd

# History in memory only, matching fish — see ~/.config/fish/conf.d/env.fish,
# which keeps its history on tmpfs. Unsetting HISTFILE is what stops the write;
# HISTFILESIZE=0 is a backstop should anything restore it.
HISTSIZE=10000
HISTFILESIZE=0
unset HISTFILE

# Secrets are not in the environment; fetch on demand with `sec NAME`.
# See ~/.secret/README.md

# Not exported: an interactive child re-sources this file and sets its own, and
# a non-interactive one has no use for a prompt.
PS1='\[\033[1;33m\]\u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]'

# Force 256-color mode; the terminal's TERM is not always trusted by tmux.
alias tmux="tmux -2"
