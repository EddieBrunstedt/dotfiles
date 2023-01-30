#!/bin/zsh

# Function to add to PATH
appendpath () {
    case ":$PATH:" in
        *:"$1":*)
            ;;
        *)
            PATH="${PATH:+$PATH:}$1"
    esac
}

# Directories to add to PATH
# All directories in '~/.local/bin'
appendpath "$(du "$HOME/.local/bin/" | cut -f2 | tr '\n' ':' | sed 's/:*$//')"
appendpath "$HOME/.yarn/bin"
appendpath "$HOME/.emacs.d/bin"
appendpath "$HOME/.deno/bin"
appendpath "$HOME/.cargo/bin"
appendpath "$HOME/.deno/"
appendpath "$HOME/.dvm/bin/"
unset appendpath

export EDITOR="$HOME/.local/bin/start-editor"
export ALTERNATE_EDITOR="emacs"
export VISUAL="$HOME/.local/bin/start-editor"
export TERMINAL="alacritty"
export BROWSER="librewolf"
export READER="zathura"
export FILE="lf"
export SUDO_ASKPASS="$HOME/.local/bin/dmenupass"
export LESSOPEN="| /usr/bin/highlight -O ansi %s 2>/dev/null"

# Default options for fzf
export FZF_DEFAULT_OPTS="--layout=reverse --height 40% --border --inline-info"
export FZF_DEFAULT_COMMAND='fd --type f --hidden'

# less/man colors
export LESS=-R
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# lsp
export LSP_USE_PLISTS=true

# dvm (deno version manager)
export DENO_INSTALL=$HOME/.deno

# Have QT use gtk2 theme
export QT_QPA_PLATFORMTHEME="gtk2"

# Fix for Java applications in dwm
export _JAVA_AWT_WM_NONREPARENTING=1

# Mozilla smooth scrolling/touchpads.
export MOZ_USE_XINPUT2="1"

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

# For when not using display manager
#
# Start graphical server if dwm not already running.
# [ "$(tty)" = "/dev/tty1" ] && ! pgrep -x dwm >/dev/null && exec startx


