#zinit self-update!/bin/zsh

export KEYTIMEOUT=1

# Disable feature for freezing terminal with Ctrl + S
stty -ixon

# Helper function to add stuff to PATH
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
appendpath "$HOME/.cargo/bin"
appendpath "$HOME/.config/emacs/bin"
appendpath "$HOME/.deno/"
appendpath "$HOME/.deno/bin"
appendpath "$HOME/.dvm/bin/"
appendpath "$HOME/.fly/bin/"
appendpath "$HOME/.yarn/bin"
appendpath "$HOME/.scripts/"
appendpath "$HOME/.go/bin"
unset appendpath

export EDITOR="nvim"
export VISUAL="nvim"
export ALTERNATE_EDITOR="nvim"
export BROWSER="librewolf"
export FILE="lf"
export LESSOPEN="| /usr/bin/highlight -O ansi %s 2>/dev/null"
export READER="zathura"
export TERMINAL="alacritty"
export XDG_CONFIG_HOME=$HOME/.config
export GOPATH=$HOME/.go
export GOBIN=$HOME/.go/bin

# Limit the man width
export MANWIDTH=80

# PNPM
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# less/man colors
export LESS=-R
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# Compile LSP in plist mode for better performance
export LSP_USE_PLISTS=true

# dvm (deno version manager)
export DENO_INSTALL=$HOME/.deno

# Have QT use gtk2 theme
export QT_QPA_PLATFORMTHEME="gtk3"

# Fix for Java applications in dwm
export _JAVA_AWT_WM_NONREPARENTING=1

# Mozilla smooth scrolling/touchpads.
export MOZ_USE_XINPUT2="1"

# Used by SSH agent
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

# Use rootless docker service
# DOC: https://wiki.archlinux.org/title/docker#Rootless_Docker_daemon
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

# Escape key timeout in ZSH shell (used by "jeffreytse/zsh-vi-mode" plugin)
ZVM_KEYTIMEOUT=0
