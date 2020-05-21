#!/bingsh

# Append to PATH
appendpath () {
    case ":$PATH:" in
        *:"$1":*)
            ;;
        *)
            PATH="${PATH:+$PATH:}$1"
    esac
}

# Adds `~/.scripts` and all subdirectories to $PATH
appendpath "$(du "$HOME/.local/bin/" | cut -f2 | tr '\n' ':' | sed 's/:*$//')"
appendpath "$(yarn global bin)"
appendpath "$HOME/.emacs.d/bin"
appendpath "$HOME/.deno/bin"
unset appendpath

export EDITOR="emacsclient -n"
export TERMINAL="alacritty"
export BROWSER="firefox"
export READER="zathura"
export FILE="lf"
export SUDO_ASKPASS="$HOME/.local/bin/tools/dmenupass"

# less/man colors
export LESS=-R
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# For when not using display manager
#
# Start graphical server if dwm not already running.
#[ "$(tty)" = "/dev/tty1" ] && ! pgrep -x dwm >/dev/null && exec startx
