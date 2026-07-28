# POSIX login-shell environment.
#
# Only two kinds of thing belong here: values that need a shell to compute, and
# $PATH. Everything else lives one layer down:
#
#   ~/.config/environment.d/*.conf   static session-wide vars, read natively by
#                                    `systemd --user` — reaches GUI apps and
#                                    user units, which never source a profile
#   ~/.config/uwsm/env               Wayland/GPU vars for the graphical session
#   ~/.config/fish/config.fish       interactive-shell-only settings
#
# uwsm sources this file and exports the delta into the systemd and D-Bus
# activation environments, so anything set here reaches every process in the
# graphical session.

# ── PATH ──
# Assembled here because it cannot be assembled anywhere else. In
# environment.d, ${PATH} expands against the generator's own environment
# (/usr/local/bin:/usr/bin), so prepending there would discard what
# /etc/profile.d/*.sh contributes — cuda, jvm, rustup, perl. A login shell has
# already run those, so prepending here is correct. Per-user systemd
# environment generators, which could compute this, do not exist: all the
# supported generator directories are system-level.
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

# pnpm puts global binaries directly in $PNPM_HOME, not in a bin/ below it.
# PNPM_HOME itself is set in environment.d/10-defaults.conf.
path_prepend "$HOME/.local/share/pnpm"
path_prepend "$HOME/.npm-global/bin"
path_prepend "$HOME/.local/share/zvm/bin"
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
