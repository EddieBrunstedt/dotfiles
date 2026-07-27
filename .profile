# XDG Base Directory
export XDG_CONFIG_HOME="$HOME/.config"

# Default applications
export ALTERNATE_EDITOR="nvim"
export BROWSER="librewolf"
export EDITOR="nvim"
export READER="zathura"
export TERMINAL="ghostty"
export VISUAL="nvim"

# Secret environment variables
secret_env_loader="$HOME/.local/bin/load-secret-env"
[ -x "$secret_env_loader" ] && eval "$("$secret_env_loader" --sh)"
unset secret_env_loader

# PATH configuration
export PNPM_HOME="$HOME/.local/share/pnpm"

path_prepend() {
    [ -d "$1" ] || return
    case ":$PATH:" in
    *:"$1":*) ;;
    *)
        PATH="$1${PATH:+:$PATH}"
        ;;
    esac
}

path_prepend "$PNPM_HOME"
path_prepend "$HOME/.yarn/bin"
path_prepend "$HOME/.local/share/zvm/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.local/bin/statusbar"
path_prepend "$HOME/.local/bin"
export PATH
unset path_prepend

# Less/Man page configuration
export LESSOPEN="| /usr/bin/highlight -O ansi %s 2>/dev/null"
export MANWIDTH=80
# R: pass ANSI colors through, F: quit if it fits one screen, X: keep output on screen after quit
export LESS=-RFX
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
export _ZO_EXCLUDE_DIRS="$HOME:$XDG_RUNTIME_DIR/*:$HOME/vault/*:$HOME/shared/downloads/*"
