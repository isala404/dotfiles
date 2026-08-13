---
name: bws-secrets
description: Use when a task touches credentials on this machine - AWS keys, kubeconfigs, SSH/GPG keys, API tokens, `bws`, `keychain-bio`, a Touch ID prompt from `aws` or `kubectl`, or restoring keys on a new Mac. macOS only.
---

# BWS secrets

**Requires:** macOS, and a host whose nix config installs this plumbing (currently only `m3-personal`). Needs `bws`, `jq`, and `~/.local/bin/keychain-bio` on the machine, plus a BWS access token already stored in the Keychain. If `keychain-bio` is missing, the machine hasn't been set up — run `sync` and see "Setting up a new machine" below rather than inventing a fallback. Never fall back to reading a credential from a file or asking the user to paste one.

Every long-lived credential on this machine (AWS keys, kubeconfig certs, SSH keys, GPG keys, API tokens) lives in Bitwarden Secrets Manager. Nothing is on disk in plaintext. The BWS access token itself sits in the macOS Keychain behind Touch ID, and a small Swift binary, `keychain-bio`, is the only thing that reads it.

The point of the design: a stolen laptop with an unlocked shell still can't dump credentials, because every fetch that isn't already cached needs a fingerprint.

## Handling rules

These come first because they are the easy thing to get wrong. A secret that reaches your context has leaked, and there is no way to un-leak it — the transcript is already written.

**Bad — the value ends up somewhere it can be read back:**

```bash
bws secret get <id> -o json | jq -r .value              # prints to the transcript
bws secret get <id> -o json | jq -r .value > /tmp/key   # plaintext on disk
echo "$TOKEN"                                            # same problem, one step removed
bws secret get <id> -o json | tee key.json | ...         # tee is a print
export AWS_SECRET_ACCESS_KEY=$(bws secret get ...)       # now in the env of every child, and in `ps` on some systems
```

**Good — the value goes straight from `bws` into the thing that needs it:**

```bash
bws secret get <id> -o json | jq -r .value | <tool that needs it>

# or scoped to one command, then out of scope
SECRET="$(bws secret get <id> -o json | jq -r .value)"
some-tool --token "$SECRET"
unset SECRET

# best: don't fetch at all, let the helper do it
aws s3 ls --profile myprofile        # credential_process handles the fetch, cache, and Touch ID
kubectl get pods                     # exec plugin does the same
```

Two more rules:

- **Prefer the existing helpers.** If a credential already has an AWS `credential_process` entry or a kubectl exec plugin entry, run `aws` / `kubectl` normally. The helper caches and gates on Touch ID; a manual fetch does neither.
- **If a task looks like it needs a secret in plaintext on disk, stop and ask.** Restoring an SSH or GPG key is the one legitimate case, and it's covered under "Setting up a new machine".

## Scope

Read and write secrets, wire up helpers, debug why a fetch failed. That's the whole job.

Don't rotate a credential, delete a secret, or change what a profile points at unless the user asked for that specific change — a rotation you weren't asked for breaks whatever else was using the old key. Don't edit `~/.aws/config`, `~/.kube/config`, or the helpers in `bin/` as a side effect of a read-only question. And when you're diagnosing, report what you found rather than "fixing" it: a stale cache file and a revoked token look identical from the outside, and deleting the wrong thing costs the user a re-auth.

## How it fits together

```
aws or kubectl
  → credential helper checks ~/.cache/bws/<kind>-<secret-id>   (1h idle timeout)
      HIT  → touch the file to renew, print cached response, done. No Touch ID, no API call.
      MISS → keychain-bio get bws-access-token
               → Touch ID cache valid (5m idle)? skip prompt : prompt (password fallback)
             → bws secret get <id>
             → write cache (mode 600), print

direct `bws ...` in fish
  → fish wrapper calls keychain-bio get bws-access-token   (same 5m Touch ID cache)
  → exports BWS_ACCESS_TOKEN for that one call
  → real bws binary. No response cache here.
```

Both caches are **idle** timeouts, not fixed windows. Every use bumps the file's mtime, so an actively used credential never re-prompts; one left alone past its timeout does.

| Path | What it is |
|---|---|
| `bin/keychain-bio.swift` | Touch ID gated Keychain read/write. Compiled by `swiftc` during `darwin-rebuild switch` to `~/.local/bin/keychain-bio` |
| `bin/bws/aws-credential-helper.sh` | AWS `credential_process`. Installed to `~/.aws/bws-credential-helper.sh` |
| `bin/bws/kube-credential-helper.sh` | kubectl exec credential plugin. Installed to `~/.kube/bws-credential-helper.sh` |
| `nix/hosts/darwin/m3-personal.nix` | Defines the fish `bws` wrapper and the activation script that builds and installs all three |
| `$TMPDIR/keychain-bio-touch-$USER` | Touch ID cache. One file for all services, mtime is the clock |
| `~/.cache/bws/aws-<id>`, `~/.cache/bws/kube-<id>` | Cached helper responses, mode 600 |

All of this plumbing is host-specific to `m3-personal`. On another host the wrapper and the helpers simply don't exist.

## Reading secrets

**In fish**, `bws` is a wrapper function that injects the token, so it just works:

```bash
bws project list                 # project IDs
bws secret list                  # every secret the service account can see
bws secret list <project-id>     # scoped to one project
bws secret get <secret-id> -o json | jq -r .value | <consumer>
```

**Outside fish** (bash scripts, the credential helpers, anything non-interactive) there is no wrapper, so export the token yourself:

```bash
export BWS_ACCESS_TOKEN=$("$HOME/.local/bin/keychain-bio" get bws-access-token)
bws secret get "$SECRET_ID" -o json | jq -r .value
```

`keychain-bio get` prints the value trimmed and without a trailing newline, so command substitution is safe.

To run a program with a whole project's secrets as environment variables without ever materializing them:

```bash
bws run --project-id <project-id> -- <command>
```

Each secret becomes an env var named after its key, so this only behaves well when the keys are POSIX-shaped names.

## Writing secrets

```bash
bws secret create <key> <value> <project-id>
bws secret edit <secret-id> --value <value>
bws secret delete <secret-id>
```

**Values starting with `-----BEGIN` break the CLI's argument parser.** Pass `--` before the value:

```bash
bws secret create <key> -- "$(cat ~/.ssh/id_ed25519)" <project-id>
```

After changing a secret that a credential helper reads, delete its cache file or the old value keeps being served for up to an hour:

```bash
rm ~/.cache/bws/aws-<secret-id>
```

### AWS credentials

The AWS helper expects one line of two space-separated pairs, nothing else:

```
AccessKeyId=AKIA... SecretAccessKey=...
```

```bash
bws secret create <name> 'AccessKeyId=AKIA... SecretAccessKey=...' <project-id>
```

It parses by splitting on spaces and cutting at the first `=`, so a value containing `=` or a stray space will silently produce a broken credential. There is no session-token support: the helper emits only `Version`, `AccessKeyId`, and `SecretAccessKey`, so this is for long-lived IAM user keys, not STS.

Then wire it up in `~/.aws/config`:

```ini
[profile myprofile]
region = us-east-1
credential_process = /Users/<you>/.aws/bws-credential-helper.sh <secret-id>
```

Delete any matching entry in `~/.aws/credentials`. A static entry there wins over `credential_process` and you'll never see the helper run.

### Kubeconfig (per context)

Store the whole flattened context as JSON:

```bash
kubectl config view --minify --flatten -o json      # copy this, don't paste it into a transcript
bws secret create <cluster>-kubeconfig '<json>' <project-id>
```

The helper reads `users[0].user.client-certificate-data` and `client-key-data` and base64-decodes them, so it only supports client-certificate clusters. Token, OIDC, or exec-based clusters need a different helper.

Then in `~/.kube/config`, replace the user's cert fields with the exec plugin:

```yaml
users:
- name: my-cluster
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: /Users/<you>/.kube/bws-credential-helper.sh
      args:
      - "<secret-id>"
      interactiveMode: Never
```

Remove `client-certificate-data` and `client-key-data` from that user. The `clusters` and `contexts` sections stay as they are.

### SSH and GPG keys

```bash
bws secret create <name> -- "$(cat ~/.ssh/id_ed25519)" <project-id>
bws secret create <name>-pub -- "$(cat ~/.ssh/id_ed25519.pub)" <project-id>
```

```bash
bws secret create <name> -- "$(gpg --armor --export-secret-keys <email>)" <project-id>
bws secret create <name>-pub -- "$(gpg --armor --export <email>)" <project-id>
```

## Tuning the timeouts

Both defaults can be overridden per command or exported for the session. The credential helpers inherit the environment of whatever spawned them, so exporting in the shell reaches `aws` and `kubectl` too.

```bash
set -x BWS_CACHE_IDLE_TIMEOUT_SECONDS 1800     # cached aws/kube responses, default 3600
set -x BWS_TOUCH_ID_IDLE_TIMEOUT_SECONDS 600   # Touch ID grace period, default 300
```

Both must be positive numbers or the tool exits with an error rather than falling back to the default.

To force a fresh prompt right now, remove the cache files:

```bash
rm -f $TMPDIR/keychain-bio-touch-$USER ~/.cache/bws/*
```

## Setting up a new machine

1. Build the tooling: `sync` (that is `darwin-rebuild switch`). This compiles `keychain-bio` and installs both helpers.
2. Get a service-account access token from the Bitwarden web vault and store it:
   ```bash
   keychain-bio store bws-access-token '<token>'
   ```
   Once per machine. `store` does **not** require Touch ID, only `get` does. It also takes the token as a command-line argument, which means it lands in shell history and is briefly visible in `ps`. Run it from `fish --private`, or clean up afterwards with `history delete --exact 'keychain-bio store bws-access-token …'`.
3. Verify: `bws secret list` should prompt for Touch ID and return JSON.
4. Restore keys, piping rather than printing:
   ```bash
   bws secret get <secret-id> -o json | jq -r .value > ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519
   bws secret get <secret-id> -o json | jq -r .value | gpg --import
   ```

## Troubleshooting

| Symptom | Cause |
|---|---|
| No Touch ID prompt at all | Cache hit, working as designed. `rm ~/.cache/bws/*` and retry to see the prompt. |
| `Failed to retrieve: The specified item could not be found in the keychain` | Token was never stored on this machine, or stored under a different macOS user. Keychain items are keyed on service name plus the current username. |
| `Authentication not available` | `LAContext` can't evaluate on this machine right now (no enrolled fingerprint, clamshell mode). The policy is `deviceOwnerAuthentication`, so a login password prompt is the normal fallback; if even that is unavailable, unlock the Mac properly. |
| `aws` reports the credential process is missing | Helper not installed. Run `sync`, then check `~/.aws/bws-credential-helper.sh` exists and is executable. |
| Credentials still stale after rotating the secret | Cached response. `rm ~/.cache/bws/aws-<secret-id>`. |
| `bws` returns 401 / 404 | Token revoked, or the secret isn't shared with the service account's project. Check in the web vault. |
| Helper works in fish but not in a script | The `bws` wrapper is a fish function, so scripts get the raw binary with no token. Export `BWS_ACCESS_TOKEN` from `keychain-bio` first. |

## Changing the plumbing

The helpers and the Swift source live in this repo under `bin/`, but the copies that actually run are installed by the nix-darwin activation script in `nix/hosts/darwin/m3-personal.nix`. Editing `bin/` alone changes nothing until `sync` runs. Both helpers are macOS-only by construction: they use `stat -f %m` and hardcode `/usr/bin/python3`.
