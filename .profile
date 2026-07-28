# POSIX login-shell environment.
#
# Almost everything that used to live here has moved one layer down, because
# uwsm's environment preloader sources this file and exports the delta into the
# systemd and D-Bus activation environments — i.e. anything set here ends up in
# the environment of every process in the graphical session:
#
#   ~/.config/environment.d/*.conf   session-wide vars (editors, pager, cursor,
#                                    SSH_AUTH_SOCK, …) — read natively by
#                                    `systemd --user`, no shell needed
#   ~/.config/uwsm/env               Wayland/NVIDIA vars for the graphical
#                                    session, sourced by uwsm before mango
#   ~/.config/fish/config.fish       interactive-shell-only settings
#
# Secrets are no longer set here, or in any shell. They live encrypted in
# ~/.secret/ and are fetched per-process with `sec NAME`. See
# ~/.secret/README.md.
#
# What stays here is what genuinely needs a POSIX shell and must be shared by
# both fish and bash.

# ── PATH ──
# PATH is assembled here on purpose. It cannot move to environment.d: that
# file's ${PATH} expands against the environment *generator's* PATH, which is
# the bare /usr/local/bin:/usr/bin — so prepending there would silently discard
# everything /etc/profile.d/*.sh contributes (cuda, jvm, rustup, perl). A login
# shell has already run those, so appending to $PATH here is correct.
#
# PNPM_HOME itself is set in environment.d/10-defaults.conf.
path_prepend() {
    [ -d "$1" ] || return
    case ":$PATH:" in
    *:"$1":*) ;;
    *)
        PATH="$1${PATH:+:$PATH}"
        ;;
    esac
}

# pnpm puts global binaries directly in $PNPM_HOME, not in a bin/ below it —
# the empty ~/.local/share/pnpm/bin is not the right entry.
path_prepend "$HOME/.local/share/pnpm"
path_prepend "$HOME/.npm-global/bin"
path_prepend "$HOME/.local/share/zvm/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.local/bin/statusbar"
path_prepend "$HOME/.local/bin"
export PATH
unset -f path_prepend

# ── less(1) colours ──
# These stay in shell config because their values are raw ESC bytes, which the
# environment.d format cannot express, and because they only affect `less` in a
# terminal — no GUI app ever reads them. Both fish and bash inherit them from
# the login shell.
#
# Built with printf rather than $'\e[…]': this file is sourced by uwsm's
# environment preloader with plain /bin/sh, and $'…' is a bashism that would
# store the literal characters if /bin/sh were ever dash.
esc=$(printf '\033')
export LESS_TERMCAP_mb="${esc}[1;32m"
export LESS_TERMCAP_md="${esc}[1;32m"
export LESS_TERMCAP_me="${esc}[0m"
export LESS_TERMCAP_se="${esc}[0m"
export LESS_TERMCAP_so="${esc}[01;33m"
export LESS_TERMCAP_ue="${esc}[0m"
export LESS_TERMCAP_us="${esc}[1;4;31m"
unset esc

# ── sops ──
# Where sops finds the age identity that decrypts ~/.secret/*.sops.yaml.
# See ~/.secret/README.md. Exports a COMMAND, not a secret — which is why it
# is safe here despite the warning at the top of this file: uwsm will push it
# into the systemd and D-Bus activation environments, and that is the intended
# outcome (waybar's protonmail shim needs it). No secret value is exposed.
export SOPS_AGE_KEY_CMD="secret-tool lookup xdg:schema dev.nilo.age name sops"

# ── zoxide ──
# Needs $XDG_RUNTIME_DIR expanded at read time, which environment.d cannot do
# for a glob-containing value without quoting surprises.
export _ZO_EXCLUDE_DIRS="$HOME:$XDG_RUNTIME_DIR/*:$HOME/vault/*:$HOME/shared/downloads/*"
