# Secrets

Encrypted secret values, tracked in git, decrypted on demand per process.

Variable names are cleartext so the inventory is reviewable in `git diff`. Values are encrypted with [age](https://age-encryption.org/) via [sops](https://github.com/getsops/sops). Nothing is loaded into any shell environment.

```
claude                                   the tool that needs the key
  └─ ~/.local/bin/shims/claude           symlink to the shim, first on $PATH
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

These are an arbitrary label, not a credential. The exact strings must match between store and lookup, and appear in three places: `.config/environment.d/10-defaults.conf`, `.config/fish/conf.d/env.fish`, and this file.

The fish copy is a conditional fallback (`set -q …; or set -gx …`) for a TTY login where nothing has read `environment.d`; under a graphical session the value inherited from `systemd --user` wins.

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

Tools that insist on reading a secret from their environment get one, via `~/.dotfiles/.local/bin/shims/`. That directory is first on `$PATH`, ahead of both `/usr/bin` and `~/.cargo/bin`.

It contains a symlink per tool plus the `manifest`, and nothing else — every *executable* in it is a tool you can type. The dispatcher they all point at lives outside `$PATH`, at `~/.local/libexec/shim`, so it cannot be invoked as a command itself. `manifest` is mode 644 and so is skipped by `$PATH` lookup; do not make it executable (it has no shebang, so a shell would read its first data line as a command and re-enter the shim). It reads `$0` to learn which tool it was invoked as, looks that name up in `manifest`, exports exactly the secrets listed, and execs the real binary.

Because `$0` is the symlink the shell resolved off `$PATH`, the dispatcher locates `manifest` and `sec` relative to the shims directory, not to its own location in `libexec`.

`manifest` is the authoritative record of **which tool can see which secret**:

```
# tool              real binary                      secrets
claude              /usr/bin/claude                  ANTHROPIC_API_KEY
codex               /usr/bin/codex                   OPENAI_API_KEY
opencode            /usr/bin/opencode                OPENROUTER_API_KEY
ord                 /usr/bin/ord                     OPENROUTER_API_KEY
protonmail-status   ~/.cargo/bin/protonmail-status   PROTON_BRIDGE_IMAP_USER PROTON_BRIDGE_IMAP_PASS
```

Columns: tool name, real binary (absolute, or `~/` for `$HOME`), then one or more secret names. Lines starting with `#` are ignored. A tool receives what is listed and nothing else — verified.

To add one:

```fish
cd ~/.dotfiles/.local/bin/shims
# append a manifest line, then:
ln -s ../../libexec/shim <tool>
cd ~/.dotfiles && just restow
```

The shim fails loudly rather than silently: unknown tool name, missing manifest, or a target that is not executable each produce a message on stderr and exit 1. A failed `sec` lookup aborts before the real binary is exec'd.

**Never `env VAR=value TOOL`.** The shim assigns and exports instead, because an `env` prefix puts the value in `/proc/<pid>/cmdline`, readable by any process on the machine for the lifetime of the command.

Creating a **new** vault file must be done in `~/.dotfiles/.secret/` followed by `just restow`. Stow symlinks files that existed when it last ran; a new path created under `~/.secret/` is a plain `$HOME` file with no counterpart in the repo, and will never be committed.

`sops FILE` exits 200 with "File has not changed, exiting" if the editor made no change. That is success.

## Background services

Systemd user units have no ambient secrets. If a unit needs one, shim the command it executes. Do not put values in `Environment=` or `EnvironmentFile=` — unit environments are readable via `systemctl --user show`.

Worked example, waybar's `custom/protonmail`:

- `~/.local/bin/shims/protonmail-status` wraps the real binary in `~/.cargo/bin`, supplying `PROTON_BRIDGE_IMAP_USER` and `PROTON_BRIDGE_IMAP_PASS`. Waybar's own environment holds neither.
- The waybar config uses an **absolute path**. Waybar inherits its `PATH` from the systemd activation environment, which does not include the shims directory, so a bare name would resolve to the real cargo binary and silently lose its credentials.
- `"interval": 60` with `"signal": 4` (`pkill -RTMIN+4 waybar`). Each tick costs two decryptions plus an IMAP round-trip, ~200ms. Signals 1–3 are taken by volume, mullvad and dunst.

Units get `SOPS_AGE_KEY_CMD` from `~/.config/environment.d/10-defaults.conf`, which `systemd --user` reads natively — no unit-level `Environment=` needed. It is a command string, not a secret, and is the one variable here that may legitimately enter the systemd/D-Bus activation environment.

Two consequences of using `environment.d`:

- A change takes effect for units on `systemctl --user daemon-reload`, but the **compositor keeps the environment it started with**, so anything it launches — terminals, and their non-fish shells — only picks it up after a re-login.
- Had this been set with a unit-level `Environment=` instead, the whole assignment would need quoting: systemd splits `Environment=` on whitespace, so the unquoted form sets `SOPS_AGE_KEY_CMD=secret-tool` and discards the rest — present, plausible to `grep`, and non-functional. `environment.d` has no such rule; the value is taken verbatim to end of line.

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
