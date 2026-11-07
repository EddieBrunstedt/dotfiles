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
cloned. `packages/hosts/<hostname>` names them so `pkgs` stays quiet; on a
machine that already has them, `pkgs install` leaves them alone.

Given a machine that boots and has a greeter, in order:

```sh
sudo pacman -S --needed git just stow  # 1. what the rest of this needs
./.local/bin/pkgs install              # 2. everything listed; not on $PATH yet
                                       # 3. build the `manual` entries by hand
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
| `wallpaper.service` | swaybg; restart it after repointing the `current` symlink |
| `filemanager-yazi.service` | `Type=dbus`, activated on demand, exits when idle |
| `protonmail-bridge.service` | waits for VPN and API reachability first |
| `vault-cleanup.service` | clears a dangling `~/vault` symlink at login |

Most session-bound processes live in `app-graphical.slice`, which is
`PartOf=graphical-session.target`, so they stop at logout. Slice placement and
lifecycle dependencies are separate: Proton Bridge (the default `app.slice`)
and packaged Dunst (`session.slice`) instead stop through a direct `PartOf=`.
Drop-ins catch the two cases that would otherwise escape the session: the
packaged ghostty daemon, and Chromium/Electron apps that move themselves into
an `app-*.scope` over D-Bus. `app.slice` itself must never be bound to the
session — it also holds the D-Bus, PipeWire and keyring sockets.

## Packages

What this desktop wants installed lives in `packages/`, one file per scope.
`pkgs` reads it straight from the repo (it is not linked into `$HOME`), so it
works before `just install`.

| List | Holds |
| --- | --- |
| `packages/common` | every machine |
| `packages/hosts/<hostname>` | this machine only: boot, firmware, GPU, and whatever this box does that others don't |
| `…/*.sops.yaml` beside either | the same, encrypted: packages that shouldn't be visible in a public repo |

`<hostname>` is `uname -n`. Each list is one package per line, with optional
tags and a comment:

```
neovim
poppler        optdep  # PDF previews in yazi
mangowm-local  manual  # built by hand with makepkg
```

- **`optdep`**: kept as an optional dependency of something installed
  (`pacman -Qi`'s "Optional For"). Installed `--asdeps`, so removing whatever
  wants it turns it into an orphan instead of leaving it behind.
- **`manual`**: exists in no repository; built with `makepkg`. `pkgs install`
  skips it, and `pkgs report --audit` says if it ever turns up in the repos or
  the AUR.

Repo and AUR packages share a list; `paru` installs both.

```sh
pkgs                                   # report: untracked, missing, wrong install reason, orphans
pkgs report --audit                    # also: listed packages that no longer exist anywhere
pkgs add [--host] [--private] NAME     # list it, installing it if needed
pkgs add --optdep NAME -m "why"        # tags and a comment
pkgs drop NAME                         # unlist and uninstall (pacman -Rns); --keep only unlists
pkgs fix                               # install reasons back in line with the lists
pkgs edit [--host] [--private]         # $EDITOR, or sops for a private list
pkgs install                           # everything listed for this machine
```

`add` moves a package that is already listed elsewhere, so
`pkgs add --host --private NAME` is also how something becomes private. For
each untracked package the report shows when it was installed and by which
command, from `/var/log/pacman.log`.

The plain report only compares the lists with the local pacman database, so it
is instant and offline; run it after installing or removing anything.
`--audit` also checks the lists against the repos (as of the last sync) and the
AUR (online), catching a listed package that was renamed or removed upstream,
which your installed copy hides until `pkgs install` fails on a fresh machine.
Run it now and then, after a large upgrade, and before relying on the lists for
a new install.

**Private lists** are encrypted with the same sops/age setup as
[Secrets](#secrets); their recipients are the `packages/` rules in
`.secret/.sops.yaml`. The whole list is one encrypted string, so the repo shows
that a private list exists, when it changed and its total length, but not how
many entries it has or what they are. Reading one needs the age identity in the
keyring: until then `pkgs` reports it as unreadable and `pkgs install` skips it,
so run `pkgs install` again once [Secrets](#secrets) works.

## Disk cleanup

The system menu's **Disk: Clean caches, build artifacts and Docker data** runs
`system-cleanup`, which takes no arguments and asks no questions. It keeps only
the installed version of each cached Pacman package (`sudo paccache`; older ones
remain on the Arch Linux Archive) and drops archives of uninstalled packages,
removes devtools build chroots, runs `docker system prune --all --force` and
prunes anonymous Docker volumes, prunes the pnpm store, verifies/garbage-collects
the npm cache, clears the tldr cache and removes project build artifacts under
`~` with `kondo --all`. A step that would race a running devtools build is
skipped and reported as failed. Named Docker volumes, application caches and Paru build
trees are left alone. Everything removed can be rebuilt or re-downloaded;
`pacman-contrib` supplies `paccache`.
See [Docker's prune documentation](https://docs.docker.com/reference/cli/docker/system/prune/).

It reports failed steps at the end and exits nonzero on partial failure; the
terminal stays open for review. Reported free-space changes also include
other activity on the measured filesystems.

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
  units. Docker also wants your user in the `docker` group.
- **Telltale** — the `telltale-*` gauges on waybar, installed to
  `~/.cargo/bin` with `cargo install --path ~/projects/telltale`.
  Self-maintained; `pkgs` only tracks pacman packages.
- **The age identity** in the login keyring, without which no secret decrypts.
- **The OpenPGP secret key used for Git commit signing.** `.gitconfig` tracks
  the public identity, key fingerprint and mandatory-signing policy, but never
  the private key. Import it from a secure backup before committing. Commits
  deliberately fail rather than fall back to unsigned when the key is absent.
