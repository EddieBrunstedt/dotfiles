# POSIX login-shell environment. uwsm sources this file and exports the delta
# into the systemd and D-Bus activation environments, so anything set here
# reaches every process in the graphical session.
#
# How this file relates to environment.d, uwsm/env and fish: see README.md.

# ── PATH ──
# Must be assembled here. In environment.d, ${PATH} expands against the
# generator's own environment (/usr/local/bin:/usr/bin), so prepending there
# would discard what /etc/profile.d/*.sh contributes — cuda, jvm, rustup, perl.
# A login shell has already run those. Per-user systemd environment generators,
# which could also compute this, do not exist.
#
# This is the only copy of the list. fish never reads this file, so for a TTY
# login ~/.config/fish/conf.d/env.fish recovers the result by running `sh -lc`
# and importing the PATH that produces — see the comment there.
path_prepend() {
    [ -d "$1" ] || return
    case ":$PATH:" in
    *:"$1":*) ;;
    *)
        PATH="$1${PATH:+:$PATH}"
        ;;
    esac
}

# pnpm 11 moved global binaries to $PNPM_HOME/bin; 10 and earlier put them
# directly in $PNPM_HOME. PNPM_HOME is set in environment.d/10-defaults.conf.
path_prepend "$HOME/.local/share/pnpm/bin"
path_prepend "$HOME/.npm-global/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.local/bin/statusbar"
path_prepend "$HOME/.local/bin"
# Last, so it wins: the shims must shadow both /usr/bin and ~/.cargo/bin.
path_prepend "$HOME/.local/bin/shims"
export PATH
unset -f path_prepend

# ── less(1) colours ──
# Raw ESC bytes, which the environment.d format cannot express. Built with
# printf rather than $'\e[…]', a bashism: uwsm sources this file with plain
# /bin/sh, which would store the escape literally if it were ever dash.
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
# Needs $XDG_RUNTIME_DIR expanded at read time, which environment.d cannot do
# for a glob-containing value without quoting surprises.
export _ZO_EXCLUDE_DIRS="$HOME:$XDG_RUNTIME_DIR/*:$HOME/vault/*:$HOME/shared/downloads/*"
