# XDG Base Directory
export XDG_CONFIG_HOME="$HOME/.config"

# Default applications
export ALTERNATE_EDITOR="nvim"
export BROWSER="librewolf"
export EDITOR="nvim"
export READER="zathura"
export TERMINAL="ghostty"
export VISUAL="nvim"

# PATH configuration
export PNPM_HOME="$HOME/.local/share/pnpm"

# Helper function to add stuff to PATH
appendpath() {
    case ":$PATH:" in
    *:"$1":*) ;;
    *)
        PATH="${PATH:+$PATH:}$1"
        ;;
    esac
}

# All directories in '~/.local/bin'
appendpath "$(du "$HOME/.local/bin" | cut -f2 | tr '\n' ':' | sed 's/:*$//')"
appendpath "$HOME/.cargo/bin"
appendpath "$HOME/.scripts"
appendpath "$HOME/.yarn/bin"
appendpath "$PNPM_HOME"
unset appendpath

# Less/Man page configuration
export LESSOPEN="| /usr/bin/highlight -O ansi %s 2>/dev/null"
export MANWIDTH=80
export LESS=-R
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# Application-specific configuration
export QT_QPA_PLATFORMTHEME="gtk3"
export _JAVA_AWT_WM_NONREPARENTING=1
export MOZ_USE_XINPUT2="1"
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
export _ZO_EXCLUDE_DIRS="/run/media/*"
