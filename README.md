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

## Fresh machine

Where the boundary sits: this repo describes a desktop, not a machine. The
bootloader, microcode, GPU driver, network hardware and the greeter belong to
whoever built the box — they are already installed by the time anything here is
cloned. `.config/applist-machine` names them so `package_report` stays quiet;
nothing installs them.

Given a machine that boots and has a greeter, in order:

```sh
sudo pacman -S --needed git just stow  # 1. what the rest of this needs
./.local/bin/package_install -b        # 2. official + AUR; not on $PATH yet
                                       # 3. build .config/applist-local by hand
just install                           # 4. symlink into $HOME
just install-session                   # 5. root-owned: uwsm session entry, no-sleep, power key
just enable-services                   # 6. user units, then log out and back in
```

Step 5 is easy to skip and fails quietly. Without it the greeter offers only
the `Mango` session that `mangowm-local` ships, which runs the compositor bare:
the session comes up looking correct while uwsm never runs, so nothing in
[Environment layers](#environment-layers) or [Session](#session) below is in
effect. Pick **Mango (UWSM)** at the greeter.

The remaining prerequisites are outside this repo entirely — see
[Not in this repo](#not-in-this-repo).

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

The compositor starts nothing itself beyond `uwsm finalize`, its one
`exec_once` in `.config/mango/config.toml`. That exports `WAYLAND_DISPLAY` and
lets `graphical-session.target` start. Everything else is a systemd user unit,
is D-Bus activated, or (MEGAsync) comes from `~/.config/autostart` via uwsm's
`xdg-desktop-autostart.target`.

| Unit | Notes |
| --- | --- |
| `waybar.service` | `ExecCondition` matches `XDG_CURRENT_DESKTOP`, so it only runs under mango |
| `swayidle.service` | locks on `loginctl lock-session` and before sleep; no idle timeout, so locking and blanking are only ever deliberate |
| `desktop-watch.service` | signals waybar's `~/desktop` segment whenever the folder changes |
| `wallpaper.service` | swaybg; restart it after repointing the `current` symlink |
| `filemanager-yazi.service` | `Type=dbus`, activated on demand, exits when idle |
| `protonmail-bridge.service` | waits for VPN and API reachability first |
| `vault-cleanup.service` | clears a dangling `~/vault` symlink at login |
| `forgejo-runner.service` | `background.slice`, outlives the session — see below |

Most session-bound processes live in `app-graphical.slice`, which is
`PartOf=graphical-session.target`, so they stop at logout. Slice placement and
lifecycle dependencies are separate: Proton Bridge (the default `app.slice`)
and packaged Dunst (`session.slice`) instead stop through a direct `PartOf=`.
Drop-ins catch the two cases that would otherwise escape the session: the
packaged ghostty daemon, and Chromium/Electron apps that move themselves into
an `app-*.scope` over D-Bus. `app.slice` itself must never be bound to the
session — it also holds the D-Bus, PipeWire and keyring sockets.

## Packages

Four lists under `.config/`, all reconciled by `package_report`:

| List | Contents |
| --- | --- |
| `applist` | official repos |
| `applist-aur` | AUR |
| `applist-local` | built by hand; `package_install` never touches these |
| `applist-machine` | boot, firmware, hardware, greeter — gitignored, per machine |

```sh
package_report            # both directions: untracked, and listed-but-missing
package_report --audit    # also check for packages that moved or disappeared
package_install -b        # official + AUR
```

Only the first two lists are installable. `applist-local` holds packages that
exist in no repository, and `applist-machine` describes hardware a machine must
already have to have booted at all — and being gitignored, it does not exist on
a fresh clone. Both exist so `package_report` counts those packages as tracked
rather than reporting them as untracked noise.

## Disk cleanup

The system menu's **Disk: Clean package and build caches** runs
`system-cleanup caches` (also the default with no argument). It retains the
newest three versions of each cached Pacman package using `sudo paccache`,
cleans unused Docker build cache, prunes the pnpm store, verifies/garbage-collects
the npm cache, and clears Go build/test and tldr caches. It leaves application
caches and Paru build trees alone. Tools may need to download or rebuild cache
contents afterwards; `pacman-contrib` supplies `paccache`.

**Docker: Delete stopped containers and unused images** runs
`system-cleanup docker-data`. It requires typing `delete` before removing all
stopped containers (including their writable layers), unused images/networks,
and unused build cache in the current Docker context. This can erase work in
stopped containers, including containers used by background jobs. It does not
prune volumes. Review needed containers/images before choosing it.
See [Docker's prune documentation](https://docs.docker.com/reference/cli/docker/system/prune/).

Each action reports failed steps at the end and exits nonzero on partial failure;
the terminal stays open for review. Reported free-space changes also include
other activity on the measured filesystems. Run the isolated regression checks
with `python3 tests/system-cleanup.test.py`; they use command doubles and never
prune real data.

## Secrets

Encrypted with sops/age, committed, decrypted per process. Nothing is loaded
into any shell environment — `sec NAME` prints one value, and tools that insist
on reading their environment get a shim. See [`.secret/README.md`](.secret/README.md).

## Not in this repo

Things a fresh machine needs that these files cannot provide:

- **A greeter whose PAM stack loads `pam_gnome_keyring`.** This is what unlocks
  the login keyring, which holds the age identity, without which no secret
  decrypts and `sec` fails. The requirement is on the greeter you use, not on
  any particular one; this machine runs greetd, and
  [`.secret/README.md`](.secret/README.md) records the exact lines. Its own
  configuration — which greeter, themed how, on which VT — is the machine's
  business and is deliberately not tracked here.
- **System services** — `greetd`, `NetworkManager`, `docker` and `atd`, each
  `sudo systemctl enable --now`. `just enable-services` only touches _user_
  units. Docker also wants your user in the `docker` group; and because a user
  unit cannot order itself against a system one, the forgejo runner cannot pull
  Docker up on its own.
- **MonoLisa** — a commercial font, installed to `/usr/local/share/fonts`.
  Only mpv's `SimpleBookmark.lua` still names it. The `monospace` alias in
  fontconfig, which ghostty and waybar use, resolves to Maple Mono from
  `applist-aur`.
- **Telltale** — the `telltale-*` gauges on waybar, installed to
  `~/.cargo/bin` with `cargo install --path ~/projects/telltale`.
  Self-maintained; not yet tracked by any applist.
- **`~/.config/forgejo-runner/runner-token`** — a registration secret. Run
  `just enable-forgejo` rather than `enable-services`; it checks for the token
  and explains how to register if it is missing.
- **`/etc/systemd/journald.conf.d/00-size.conf`** — `SystemMaxUse=500M`, so
  `system-cleanup` does not have to vacuum the journal by hand. Root-owned.
- **The age identity** in the login keyring, without which no secret decrypts.
- **The OpenPGP secret key used for Git commit signing.** `.gitconfig` tracks
  the public identity, key fingerprint and mandatory-signing policy, but never
  the private key. Import it from a secure backup before committing. Commits
  deliberately fail rather than fall back to unsigned when the key is absent.
