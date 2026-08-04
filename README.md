# dotfiles

Arch Linux, Wayland, [MangoWC](https://github.com/DreamMaoMao/mango) under
[uwsm](https://github.com/Vladimir-csp/uwsm), fish as the login shell. Managed
with GNU stow.

```sh
just install          # symlink everything into $HOME
just enable-services  # user units, once per machine
just restow           # after adding or removing a file
```

`just` with no arguments lists every recipe.

## Environment layers

Four files set environment variables, and which one a variable belongs in
depends on who has to see it.

| Layer | Holds | Read by |
| --- | --- | --- |
| `.profile` | `$PATH`, and values needing a shell to compute (command substitution, raw escapes) | login shells; uwsm exports the delta into the systemd and D-Bus activation environments |
| `.config/environment.d/*.conf` | static session-wide variables | `systemd --user`, natively — so user units and GUI apps, which never source a profile |
| `.config/uwsm/env` | Wayland/GPU variables | uwsm's environment preloader, before the compositor starts |
| `.config/fish/conf.d/env.fish` | interactive-shell settings | fish only |

`$PATH` is assembled in `.profile` and nowhere else. `environment.d` cannot
build it: `${PATH}` there expands against the generator's own environment, which
would discard what `/etc/profile.d/*.sh` contributes. fish never reads
`.profile`, so for a TTY login `env.fish` recovers the result by asking a POSIX
login shell for it rather than restating the list.

`environment.d` is not a shell script and not a unit file: plain `KEY=value`
only, no command substitution, no `export`, no `%h`/`%t` specifiers, no C
escapes. Anything needing those goes in `.profile` or `uwsm/env`.

## Session

The compositor starts almost nothing itself. `exec-once` in
`.config/mango/config.conf` runs `uwsm finalize` — which exports
`WAYLAND_DISPLAY` and lets `graphical-session.target` start — and the one-shot
script that places startup apps on their home tags. Everything else is a
systemd user unit or is D-Bus activated.

| Unit | Notes |
| --- | --- |
| `waybar.service` | `ExecCondition` matches `XDG_CURRENT_DESKTOP`, so it only runs under mango |
| `wallpaper.service` | swaybg; restart it after repointing the `current` symlink |
| `filemanager-yazi.service` | `Type=dbus`, activated on demand, exits when idle |
| `protonmail-bridge.service` | waits for VPN and API reachability first |
| `vault-cleanup.service` | clears a dangling `~/vault` symlink at login |
| `forgejo-runner.service` | `background.slice`, outlives the session — see below |

Session-bound processes live in `app-graphical.slice`, which is
`PartOf=graphical-session.target`, so they stop at logout. Drop-ins catch the
two cases that would otherwise escape it: the packaged ghostty daemon, and
Chromium/Electron apps that move themselves into an `app-*.scope` over D-Bus.
`app.slice` itself must never be bound to the session — it also holds the D-Bus,
PipeWire and keyring sockets.

## Packages

Four lists under `.config/`, all reconciled by `package_report`:

| List | Contents |
| --- | --- |
| `applist` | official repos |
| `applist-aur` | AUR |
| `applist-local` | built by hand; `package_install` never touches these |
| `applist-machine` | boot, firmware, hardware — gitignored, per machine |

```sh
package_report            # both directions: untracked, and listed-but-missing
package_report --audit    # also check for packages that moved or disappeared
package_install -A        # official + AUR + machine
```

## Secrets

Encrypted with sops/age, committed, decrypted per process. Nothing is loaded
into any shell environment — `sec NAME` prints one value, and tools that insist
on reading their environment get a shim. See [`.secret/README.md`](.secret/README.md).

## Not in this repo

Things a fresh machine needs that these files cannot provide:

- **MonoLisa** — a commercial font, installed to `/usr/local/share/fonts`.
  Referenced by dunst, rofi, and via `monospace` in fontconfig.
- **`~/.cargo/bin` binaries** — `cpubusy`, `routebps` and `protonmail-status`
  back three waybar segments. Self-maintained; not yet tracked by any applist.
- **`~/.config/forgejo-runner/runner-token`** — a registration secret. Run
  `just enable-forgejo` rather than `enable-services`; it checks for the token
  and explains how to register if it is missing.
- **`/etc/systemd/journald.conf.d/00-size.conf`** — `SystemMaxUse=500M`, so
  `system-cleanup` does not have to vacuum the journal by hand. Root-owned.
- **The age identity** in the login keyring, without which no secret decrypts.
