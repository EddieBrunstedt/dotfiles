# `~/.secret/` — encrypted secrets, decrypted on demand

## 1. What this is

Secrets live here as an **encrypted, git-tracked file per machine**. Variable *names* stay in
cleartext so the inventory is reviewable in `git diff`; *values* are encrypted with
[age](https://age-encryption.org/) via [sops](https://github.com/getsops/sops). Nothing is loaded
into any shell's environment. Each value is decrypted on demand and reaches only the one process
that asked for it.

```
   claude                                    (the app that needs the key)
     │
     └─ shim: ~/.local/bin/claude
          │
          └─ sec ANTHROPIC_API_KEY
               │
               └─ sops -d --extract '["ANTHROPIC_API_KEY"]' env.optimusprime.sops.yaml
                    │
                    ├─ SOPS_AGE_KEY_CMD → secret-tool lookup ... → age identity   ← only keyring use
                    └─ prints the value on stdout
```

## 2. The two layers

| Layer | What | Where |
|---|---|---|
| Vault | encrypted values + cleartext manifest | `~/.dotfiles/.secret/*.sops.yaml`, in git; stowed to `~/.secret/` |
| Key custody | one age identity | GNOME keyring, PAM-unlocked at login |

The keyring holds **only the age identity** — one secret instead of six.

**"Why not just keep the age identity in a `0600` file?"** Because the root filesystem on this
machine is **not encrypted** (`/dev/sda3`, plain ext4, no LUKS), and neither is swap (`sda2`). A
key file at `~/.config/sops/age/keys.txt` would be readable by anyone who boots a USB stick, and
since the vault itself is in a public-ish git repo, that would make the whole thing trivially
openable. The keyring's `login` collection is encrypted at rest with the login password and
unlocked by `pam_gnome_keyring.so` at login, so the identity is never at rest in the clear.

## 3. Files

The directory **is stowed**: `~/.secret/` and `~/.dotfiles/.secret/` are the same files, reached
through symlinks. Read and edit either way.

| File | Holds | Secret? |
|---|---|---|
| `.sops.yaml` | which age recipients each file encrypts to — **public keys only** | no |
| `.gitignore` | allow-list; blocks anything that isn't an encrypted file | no |
| `README.md` | this file | no |
| `env.optimusprime.sops.yaml` | this machine's values | values encrypted |
| `env.shared.sops.yaml` | values shared across all machines | values encrypted |

Where the six values live:

| File | Values | Why |
|---|---|---|
| `env.shared.sops.yaml` | `RAPIDAPI_KEY` | account-scoped; quotas are per-account, so splitting per machine buys nothing |
| | `PROTON_BRIDGE_IMAP_USER` | the Proton account address — identical on every machine |
| `env.optimusprime.sops.yaml` | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY` | plausibly revoked or attributed per machine |
| | `PROTON_BRIDGE_IMAP_PASS` | Bridge issues a distinct IMAP password per installation |

The Proton pair is deliberately split across the two files. `sec` reassembles it transparently —
`protonmail-status` reads one value from each and never knows the difference.

> **Editing an existing vault file via `~/.secret/` is fine; creating a new one must be done in
> `~/.dotfiles/.secret/`, followed by `just restow`.**
>
> Stow symlinks the files that existed when it last ran. A *new* path created under `~/.secret/`
> is an ordinary `$HOME` file with no counterpart in the repo, so it would never be committed —
> and would be lost on the next machine. This is the most likely way for a future secret to end up
> untracked.

Two sops behaviours worth knowing:

- **`sops $FILE` exits 200 with "File has not changed, exiting"** if you quit the editor without
  editing. That is success, not failure.
- sops writes **in place**. Editing through the `~/.secret/` symlink does not replace it with a
  regular file; the symlink and inode survive `sops set`, the editor flow, and `updatekeys`.

## 4. Daily use

```fish
sops ~/.secret/env.optimusprime.sops.yaml             # add or change a secret
sec OPENAI_API_KEY                                    # read one value
curl -H "Authorization: Bearer $(sec OPENAI_API_KEY)" # fish (4.x) and bash both
```

nushell:

```nu
http get -H ["Authorization" $"Bearer (sec OPENAI_API_KEY)"] $url
```

`sec` prints with **no trailing newline**, so `$(sec NAME)` is byte-exact.

Machine file wins over shared: `sec` tries `env.$HOSTNAME.sops.yaml` first, then
`env.shared.sops.yaml`, and exits 1 with a message on stderr if the name is in neither.

## 5. The behavioural change — read this before assuming something is broken

**`$OPENAI_API_KEY` is empty in a shell now. That is by design.** Secrets are no longer exported
into any shell environment, interactive or otherwise. The replacement idiom is `$(sec NAME)`, or a
shim for tools that insist on reading the environment.

If a tool suddenly cannot authenticate, the question is not "did the keyring break" but "does this
tool have a shim".

## 6. Adding a new secret

1. `sops ~/.secret/env.optimusprime.sops.yaml` — or `env.shared.sops.yaml` if every machine gets
   the same value. (Creating a *brand new* file? See the rule in §3.)
2. Add a `NAME: value` line. Save.
3. If a tool needs it in its environment, add a shim in `~/.dotfiles/.local/bin/`:

   ```sh
   #!/bin/sh
   # Runs /usr/bin/TOOL with only the key it needs. See ~/.secret/README.md
   set -eu
   SOME_API_KEY=$(sec SOME_API_KEY)
   export SOME_API_KEY
   exec /usr/bin/TOOL "$@"
   ```

   `chmod 755`, then `just restow`. `~/.local/bin` precedes `/usr/bin` on `$PATH`, so the shim
   shadows the real binary.

   **The rule that makes this safe:** assign to a variable and `export` it. Never
   `env VAR=value TOOL`, which exposes the value in `/proc/<pid>/cmdline` to every process on the
   machine for the lifetime of the command.
4. `just restow` and commit. The diff will show `ENC[...]`, never the value.

## 6b. Background services (systemd user units)

This is the case that was silently broken before, and the least obvious one.

**Systemd user units have no ambient secrets, by design.** They are not shells; nothing sources a
profile for them. If a unit needs a secret, **shim the command it executes** — do not put values in
`Environment=` or an `EnvironmentFile=`, because unit environments are world-readable via
`systemctl --user show`.

Worked example, `custom/protonmail` in waybar:

- `~/.local/bin/protonmail-status` is a shim wrapping the real Rust binary in `~/.cargo/bin`,
  supplying `PROTON_BRIDGE_IMAP_USER` and `PROTON_BRIDGE_IMAP_PASS`.
- Waybar's own environ holds **neither** value — only the short-lived shim process does.

Three gotchas, all learned the hard way:

- **Use an absolute path in the waybar config.** Waybar's `PATH` puts `~/.local/bin` first, but an
  interactive shell puts `~/.cargo/bin` first, so a bare `protonmail-status` resolves to a
  *different program* in the two contexts.
- **Tune the interval.** Every tick costs two sops decryptions plus an IMAP round-trip, ~200ms
  total on this machine. At the old `"interval": 5` that was ~17k decryptions a day for a mail
  counter, so the interval went 5 → 60 and gained `"signal": 4` for manual refresh
  (`pkill -RTMIN+4 waybar`). Signals 1, 2 and 3 were already taken by volume, mullvad and dunst.
- **Quote `Environment=` in the unit file.** `waybar.service` sets `SOPS_AGE_KEY_CMD` so the bar
  does not depend on uwsm having sourced `~/.profile`. systemd splits `Environment=` on
  whitespace, so the *unquoted* form silently sets `SOPS_AGE_KEY_CMD=secret-tool` and discards the
  rest — the variable is present, looks right to `grep -c`, and does not work. The whole
  assignment must be inside double quotes.

`SOPS_AGE_KEY_CMD` is a **command string, not a secret**, which is why it is safe in a unit file,
in `conf.d/`, in `~/.profile`, and in git. It is also the one variable that *may* legitimately
enter the systemd/D-Bus activation environment.

## 7. Adding a second machine

1. On the new machine, generate an identity and store it in **its own** keyring:
   ```sh
   id=$(age-keygen | grep -v '^#')
   printf '%s' "$id" | secret-tool store --label='sops age identity' \
       xdg:schema dev.nilo.age name sops
   printf '%s\n' "$id" | age-keygen -y      # note the public key
   unset id
   ```
2. Add a rule to `.sops.yaml` for `env.<newhost>.sops.yaml` with that public key.
3. Add the same public key to the `env.shared` rule, comma-separated.
4. **From an existing machine:** `sops updatekeys .secret/env.shared.sops.yaml`

**Editing `.sops.yaml` alone does nothing to files that are already encrypted.** Creation rules
apply at creation. `updatekeys` is what rewraps the data key for the new recipient; the encrypted
values themselves are untouched.

## 8. Recovery, and the rotatable-only rule

There is no backdoor. Without the age identity, the encrypted values are gone.

**A copy of the identity has been escrowed off this machine** (operator's decision, 2026-07-28).
Where it lives is deliberately not recorded here.

Even without escrow this would be survivable, and that reasoning is worth keeping: every value in
the vault today can be reissued — the four API keys in their provider consoles, the Bridge password
in the Proton Bridge UI, and `PROTON_BRIDGE_IMAP_USER` is an account address, not a credential.
Losing the key would cost an afternoon of rotation, not data. It would also not cost the
*inventory*: because sops keeps names in cleartext, `git show -- .secret/` still says exactly what
needs rotating.

> **This vault holds only rotatable secrets.**
>
> The moment something non-rotatable goes in — a recovery code, a TOTP seed, a license key, a
> password to an account with no self-service reset — the reasoning above stops holding, and
> escrowing the identity stops being optional.

### Outstanding: these values have never been rotated

**Every value in this vault should still be treated as compromised.** All six were confirmed
present in `systemctl --user show-environment` under the design that preceded `secret-env` — i.e.
in the environment block of every process in the graphical session, including Steam, Vesktop and
every browser content process. They have not been rotated since.

Migrating them here re-encrypted the same exposed values; it did not fix this. Rotation was
**explicitly deferred by the operator on 2026-07-28**, with the migration itself taking priority.

| Value | Where to rotate |
|---|---|
| `ANTHROPIC_API_KEY` | console.anthropic.com |
| `OPENAI_API_KEY` | platform.openai.com |
| `OPENROUTER_API_KEY` | openrouter.ai/keys |
| `RAPIDAPI_KEY` | rapidapi.com/developer |
| `PROTON_BRIDGE_IMAP_PASS` | Proton Bridge UI — regenerate the IMAP credential |

`PROTON_BRIDGE_IMAP_USER` is an account address, not a credential; nothing to rotate. Note the
Bridge password leaked alongside the API keys and is easy to overlook, because the earlier audit
wrongly classified it as unused (§9).

For each: issue the new value, revoke the old one, then `sops ~/.secret/env.<file>.sops.yaml`,
replace the value, save, commit. Verify with `sec NAME` and by running the consuming tool; for the
Bridge password, `pkill -RTMIN+4 waybar` and confirm the counter still renders.

## 9. What this replaced, and why

It replaced `~/.local/bin/secret-env`, a 259-line bespoke shell script that pulled six secrets out
of the GNOME keyring and exported all of them into every interactive shell. See
`~/secret-env-current-approach.md` for the full description.

The failure that produced it: the arrangement *before* `secret-env` kept secrets in a `0600` file
sourced from `~/.profile`, and uwsm sources `~/.profile` into the systemd and D-Bus **activation
environments** — putting all six keys into the environment block of every process in the graphical
session. `secret-env` fixed that by loading them only in interactive shells. This design goes
further and removes them from ambient environments entirely.

**Residual limitation, stated honestly:** any process running as this user can still just call
`sec`. That is inherent to unattended decryption — the keyring is unlocked, so anything with your
UID can reach it. What changed is that a secret is no longer sitting in readable memory of every
shell and every GUI app by default; it now exists briefly, in one process, on demand.

### A correction to the record

`~/secret-env-current-approach.md` §6.8 states that `PROTON_BRIDGE_IMAP_USER` and
`PROTON_BRIDGE_IMAP_PASS` have no known consumer, and §6.9 states that no systemd user unit
currently needs a secret. **Both are wrong.** Waybar's `custom/protonmail` module runs
`protonmail-status`, which reads both from the environment — and, being a systemd user unit, never
received them. The module had been **silently broken** since the migration described in §2: no
output, exit 0, no error anywhere. This migration is what fixed it.

The audit missed it because `protonmail-status` is a **compiled Rust binary** in `~/.cargo/bin`,
not a script in the dotfiles repo, so a text search for `PROTON_BRIDGE` found nothing.

> **The lesson worth writing down: a grep for variable names finds shell scripts, not binaries.**

## 10. Known limitations

- **Unencrypted root filesystem and unencrypted swap.** Decrypted values live in process memory and
  can reach disk via swap. This is the reason the age identity is in the keyring rather than a file,
  but it bounds how much that buys.
- **Any process running as this user can call `sec`.** Inherent to unattended decryption; see §9.
- **Systemd units need a shim per command.** A unit that needs a secret *without* exec'ing a
  wrappable command would need `LoadCredentialEncrypted=` or its own arrangement.
- **Decryption is not free.** ~21ms for a value in the machine file, ~41ms for one in
  `env.shared.sops.yaml` — a shared value costs double because `sec` tries the machine file first
  and misses, spawning sops twice. Fine for a per-process fetch; not something to put in a tight
  loop or a one-second poll. (For reference, the waybar shim totals ~200ms, but ~128ms of that is
  the Rust binary's own IMAP round-trip, not encryption.)
- **The vault is only as private as the repo.** Values are encrypted, but variable names, file
  names, and commit history are not. That is a deliberate trade for reviewability.
