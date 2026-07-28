# Secrets

Encrypted secret values, tracked in git, decrypted on demand per process.

Variable names are cleartext so the inventory is reviewable in `git diff`. Values are encrypted with [age](https://age-encryption.org/) via [sops](https://github.com/getsops/sops). Nothing is loaded into any shell environment.

```
claude                                   the tool that needs the key
  └─ ~/.local/bin/shims/claude           symlink to _shim, first on $PATH
       └─ sec ANTHROPIC_API_KEY          per the shims manifest
            └─ sops -d --extract '["ANTHROPIC_API_KEY"]' env.optimusprime.sops.yaml
                 ├─ SOPS_AGE_KEY_CMD → secret-tool → age identity from the keyring
                 └─ value on stdout
```

Two independent layers:

| Layer       | Contents                          | Location                                  |
| ----------- | --------------------------------- | ----------------------------------------- |
| Vault       | encrypted values, cleartext names | `~/.dotfiles/.secret/*.sops.yaml`, in git |
| Key custody | one age identity                  | GNOME keyring, PAM-unlocked at login      |

The age identity is kept in the keyring rather than a key file because this machine's root filesystem and swap are unencrypted (`/dev/sda3`, `/dev/sda2`, plain ext4, no LUKS). A key file would be readable from any live USB, and the vault ships to a git remote. The keyring's `login` collection is encrypted at rest with the login password.

## Requirements

`sops`, `age`, `libsecret` (`secret-tool`), `gnome-keyring`, `stow`, `just`.

The keyring must be PAM-unlocked at login. On this machine that is `pam_gnome_keyring.so
auto_start` in `/etc/pam.d/greetd`, which covers the graphical session.

**`/etc/pam.d/login` does not include `pam_gnome_keyring`.** A TTY login therefore does not unlock the keyring itself; it works only while a graphical session is concurrently logged in, because all sessions for this user share one systemd user instance and one D-Bus user bus, and the collection is already unlocked there. A cold boot straight to a TTY leaves the keyring locked and `sec` will fail. To fix that, add `pam_gnome_keyring.so` to `/etc/pam.d/login` (`auth optional` plus `session optional … auto_start`), matching the greetd stack.

## Layout

`.secret/` is stowed: `~/.secret/` and `~/.dotfiles/.secret/` are the same files via symlinks.

| File                       | Contents                                          | Sensitive        |
| -------------------------- | ------------------------------------------------- | ---------------- |
| `.sops.yaml`               | age recipients per file — public keys             | no               |
| `.gitignore`               | allow-list; only encrypted files may be committed | no               |
| `README.md`                | this file                                         | no               |
| `env.<hostname>.sops.yaml` | machine-specific values                           | values encrypted |
| `env.shared.sops.yaml`     | values common to all machines                     | values encrypted |

Current contents:

| File                         | Values                                                                                 |
| ---------------------------- | -------------------------------------------------------------------------------------- |
| `env.optimusprime.sops.yaml` | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `PROTON_BRIDGE_IMAP_PASS` |
| `env.shared.sops.yaml`       | `RAPIDAPI_KEY`, `PROTON_BRIDGE_IMAP_USER`                                              |

Placement rule: a value goes in the shared file if it is identical on every machine (account-scoped keys, account addresses); in the machine file if it is issued or revoked per machine. The Proton pair is split accordingly — `sec` reassembles it transparently.

The keyring item holding the age identity is filed under two lookup attributes:

```fish
secret-tool lookup xdg:schema dev.dotfiles.age name sops
```

These are an arbitrary label, not a credential. The exact strings must match between store and lookup, and appear in four places: `.config/fish/conf.d/sops.fish`, `.profile`, `.config/systemd/user/waybar.service`, and this file.

## Daily use

```fish
sec OPENAI_API_KEY                                    # read one value
sops ~/.secret/env.optimusprime.sops.yaml             # add or change values
curl -H "Authorization: Bearer $(sec OPENAI_API_KEY)" # fish 4.x and bash
```

```nu
http get -H ["Authorization" $"Bearer (sec OPENAI_API_KEY)"] $url
```

`sec NAME` resolves `env.$HOSTNAME.sops.yaml` first, then `env.shared.sops.yaml`; exits 1 with a message on stderr if the name is in neither. Output has no trailing newline, so `$(sec NAME)` is byte-exact.

**Secrets are not in the environment.** `$OPENAI_API_KEY` is empty in a shell. Use `$(sec NAME)`, or a shim for tools that read the environment.

Cost: ~21ms for a machine-file value, ~41ms for a shared-file value (two sops invocations, since the machine file is tried first). Not suitable for tight loops or sub-minute polling.

## Adding a secret

1. `sops ~/.secret/env.<file>.sops.yaml`, add a `NAME: value` line, save.
2. If a tool reads it from the environment, give it a shim — see below.
3. Commit. The diff shows `ENC[...]`, never the value.

## Shims

Tools that insist on reading a secret from their environment get one, via
`~/.dotfiles/.local/bin/shims/`. That directory is first on `$PATH`, ahead of both `/usr/bin` and
`~/.cargo/bin`.

It contains one real script, `_shim`, plus a symlink per tool. `_shim` reads `$0` to learn which
tool it was invoked as, looks that name up in `manifest`, exports exactly the secrets listed, and
execs the real binary.

`manifest` is the authoritative record of **which tool can see which secret**:

```
# tool              real binary                      secrets
claude              /usr/bin/claude                  ANTHROPIC_API_KEY
codex               /usr/bin/codex                   OPENAI_API_KEY
opencode            /usr/bin/opencode                OPENROUTER_API_KEY
protonmail-status   ~/.cargo/bin/protonmail-status   PROTON_BRIDGE_IMAP_USER PROTON_BRIDGE_IMAP_PASS
```

Columns: tool name, real binary (absolute, or `~/` for `$HOME`), then one or more secret names.
Lines starting with `#` are ignored. A tool receives what is listed and nothing else — verified.

To add one:

```fish
cd ~/.dotfiles/.local/bin/shims
# append a manifest line, then:
ln -s _shim <tool>
cd ~/.dotfiles && just restow
```

`_shim` fails loudly rather than silently: unknown tool name, missing manifest, or a target that
is not executable each produce a message on stderr and exit 1. A failed `sec` lookup aborts before
the real binary is exec'd.

**Never `env VAR=value TOOL`.** `_shim` assigns and exports instead, because an `env` prefix puts
the value in `/proc/<pid>/cmdline`, readable by any process on the machine for the lifetime of the
command.

Creating a **new** vault file must be done in `~/.dotfiles/.secret/` followed by `just restow`. Stow symlinks files that existed when it last ran; a new path created under `~/.secret/` is a plain `$HOME` file with no counterpart in the repo, and will never be committed.

`sops FILE` exits 200 with "File has not changed, exiting" if the editor made no change. That is success.

## Background services

Systemd user units have no ambient secrets. If a unit needs one, shim the command it executes. Do not put values in `Environment=` or `EnvironmentFile=` — unit environments are readable via `systemctl --user show`.

Worked example, waybar's `custom/protonmail`:

- `~/.local/bin/shims/protonmail-status` wraps the real binary in `~/.cargo/bin`, supplying `PROTON_BRIDGE_IMAP_USER` and `PROTON_BRIDGE_IMAP_PASS`. Waybar's own environment holds neither.
- The waybar config uses an **absolute path**. Waybar inherits its `PATH` from the systemd activation environment, which does not include the shims directory, so a bare name would resolve to the real cargo binary and silently lose its credentials.
- `"interval": 60` with `"signal": 4` (`pkill -RTMIN+4 waybar`). Each tick costs two decryptions plus an IMAP round-trip, ~200ms. Signals 1–3 are taken by volume, mullvad and dunst.

`waybar.service` sets `SOPS_AGE_KEY_CMD` itself so the bar does not depend on uwsm having sourced `~/.profile`:

```ini
Environment="SOPS_AGE_KEY_CMD=secret-tool lookup xdg:schema dev.dotfiles.age name sops"
```

**The quotes are load-bearing.** systemd splits `Environment=` on whitespace; unquoted, this sets `SOPS_AGE_KEY_CMD=secret-tool` and discards the rest. The variable is then present and looks correct to `grep`, but does not work.

`SOPS_AGE_KEY_CMD` is a command string, not a secret. It is safe in unit files, `conf.d/`, `~/.profile`, and git, and is the one variable here that may legitimately enter the systemd/D-Bus activation environment.

## New machine

Two cases. Both end with the new host able to decrypt.

### The previous machine is gone — restore from escrow

1. Install requirements. Clone the dotfiles repo.
2. Restore the escrowed identity into the new keyring:

   ```sh
   printf '%s' 'AGE-SECRET-KEY-1...' | secret-tool store \
       --label='sops age identity' xdg:schema dev.dotfiles.age name sops
   ```

3. `just install`, then open a new shell so `SOPS_AGE_KEY_CMD` is set.
4. `sec RAPIDAPI_KEY` should work immediately — the restored identity is a recipient of both files.
5. Rename the machine file to the new hostname and re-encrypt it to a fresh identity if you want the old key retired (see below). Otherwise `sec` will not find machine-scoped values, because it looks for `env.$HOSTNAME.sops.yaml`.

Without the escrowed identity the encrypted values are unrecoverable. See _Key custody_ below.

### Adding a machine alongside an existing one

On the new machine:

```sh
id=$(age-keygen | grep -v '^#')
printf '%s' "$id" | secret-tool store --label='sops age identity' \
    xdg:schema dev.dotfiles.age name sops
printf '%s\n' "$id" | age-keygen -y      # public key
unset id
```

Then:

1. Add a `creation_rules` entry in `.sops.yaml` for `env.<newhost>.sops.yaml` with that public key.
2. Add the same public key to the `env.shared` rule, comma-separated.
3. **From a machine that can already decrypt:** `sops updatekeys .secret/env.shared.sops.yaml`
4. Create `env.<newhost>.sops.yaml` in `~/.dotfiles/.secret/`, then `just restow`.
5. Commit and pull.

Editing `.sops.yaml` alone does nothing to files that are already encrypted — creation rules apply at creation. `updatekeys` rewraps the data key for the new recipient; encrypted values are untouched.

## Key custody

The age identity is the only thing that decrypts the vault. There is no backdoor.

A copy is escrowed off this machine (2026-07-28). Its location is deliberately not recorded here. Verify a stored copy by piping it to `age-keygen -y` and confirming it prints the public key in `.sops.yaml`.

Losing the identity means the values are gone and must be **replaced, not recovered**: generate a new identity, update `.sops.yaml`, recreate the vault files, and reissue every credential at its provider. The inventory survives regardless — names are cleartext, so `git show -- .secret/` lists exactly what needs reissuing.

> **This vault holds only rotatable secrets.**
>
> That constraint is what makes losing the identity an inconvenience rather than a loss. Anything non-rotatable — TOTP seeds, recovery codes, license keys, credentials for accounts without self-service reset — breaks it.

Rotating a value means revoking the old credential at the provider, not merely overwriting it. Superseded ciphertext remains in git history and stays decryptable by anyone who later obtains the key.

## Limitations

- Unencrypted root filesystem and swap: decrypted values in process memory can reach disk.
- Any process running as this user can call `sec`. Inherent to unattended decryption.
- Systemd units require a shim per command. A unit needing a secret without exec'ing a wrappable command would need `LoadCredentialEncrypted=`.
- The repo has a remote (`git@gitlab.com:EddieBrunstedt/dotfiles.git`). Values are encrypted; variable names, file names and commit history are not.

## Outstanding

**The five rotatable values have never been rotated and should be treated as compromised.** They were present in `systemctl --user show-environment` under an earlier arrangement, and therefore in the environment of every process in the graphical session. At least one `env` dump containing all of them was captured into `~/.claude/history.jsonl` on 2026-06-12. Migrating them here re-encrypted the same exposed values.

Rotation was deferred on 2026-07-28.

| Value                     | Reissue at             |
| ------------------------- | ---------------------- |
| `ANTHROPIC_API_KEY`       | console.anthropic.com  |
| `OPENAI_API_KEY`          | platform.openai.com    |
| `OPENROUTER_API_KEY`      | openrouter.ai/keys     |
| `RAPIDAPI_KEY`            | rapidapi.com/developer |
| `PROTON_BRIDGE_IMAP_PASS` | not independently rotatable — see below |

`PROTON_BRIDGE_IMAP_USER` is an account address, not a credential.

For each: issue the new value, revoke the old, `sops ~/.secret/env.<file>.sops.yaml`, replace, save, commit. Verify with `sec NAME` and by running the consuming tool.

### The Bridge IMAP password cannot be rotated locally

Established empirically on 2026-07-28 with Bridge 3.25.0. Do not repeat this.

Only `protonmail-bridge-core` is installed — no GUI — and the CLI has no regenerate-password
command (`login`, `logout`, `list`, `info`, `delete`, `clear`, `change`, `repair`, …). Neither of
the obvious approaches works:

- `logout <n>` then `login` — password unchanged. Logout only disconnects; the vault entry
  survives.
- `delete <n>` then `login` — password unchanged, despite the vault entry genuinely being
  destroyed and rebuilt. Bridge's own log confirms `Deleting vault user` followed by
  `Adding vault user` / `Creating new user`.

`BridgePass` is therefore not a random local token. It derives from account-side material keyed by
the Proton `userID`, which is unchanged by any local operation. `clear` would wipe preferences as
well but re-login yields the same `userID`, so it will not help either.

**The only lever is changing the Proton account password** at account.proton.me. Verify with
`info 0` afterwards rather than assuming — that step is inference, not something confirmed here.

Weigh it accordingly: this credential authenticates only against `127.0.0.1:1143` and `:1025`, is
not reachable off the machine, and anyone able to use it already has code execution as this user
and could call `sec` directly. Changing the account password forces re-login on every device. It
is reasonable to treat this as lower priority than the four API keys, which are remotely
exploitable and cheap to reissue.

After changing it, read the new value with `info 0` in `protonmail-bridge-core --cli` (stop the
service first — it runs `--noninteractive`), then:

```fish
sops ~/.secret/env.optimusprime.sops.yaml     # replace PROTON_BRIDGE_IMAP_PASS
pkill -RTMIN+4 waybar
```

Confirm the counter renders. `protonmail-status` is the only consumer of this credential — no mail
client is configured against Bridge — so nothing else needs updating.

Bridge listens on `127.0.0.1:1143` (IMAP) and `127.0.0.1:1025` (SMTP) only. This credential is not
a Proton account password and is not reachable off the machine; it grants local mailbox access.
