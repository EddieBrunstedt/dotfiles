# POSIX login environment. uwsm sources it and exports the result to the
# whole graphical session. See README.md for how the env layers divide up.

# ── PATH ──
# The only copy of the list; fish's env.fish asks `sh -l` for it.
path_prepend() {
    [ -d "$1" ] || return
    case ":$PATH:" in
    *:"$1":*) ;;
    *)
        PATH="$1${PATH:+:$PATH}"
        ;;
    esac
}

path_prepend "$HOME/.local/share/pnpm/bin"
path_prepend "$HOME/.npm-global/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.local/bin/statusbar"
path_prepend "$HOME/.local/bin"
# Last so the shims shadow everything else.
path_prepend "$HOME/.local/bin/shims"
export PATH
unset -f path_prepend

# ── less colours ──
esc=$(printf '\033')
export LESS_TERMCAP_mb="${esc}[1;32m"
export LESS_TERMCAP_md="${esc}[1;32m"
export LESS_TERMCAP_me="${esc}[0m"
export LESS_TERMCAP_se="${esc}[0m"
export LESS_TERMCAP_so="${esc}[01;33m"
export LESS_TERMCAP_ue="${esc}[0m"
export LESS_TERMCAP_us="${esc}[1;4;31m"
unset esc

# ── zoxide ──
export _ZO_EXCLUDE_DIRS="$HOME:$XDG_RUNTIME_DIR/*:$HOME/vault/*:$HOME/shared/downloads/*"
