# secretctl

`secretctl` is a policy-enforcing frontend for Bitwarden Secrets Manager. It uses one BWS machine-account token, maps arbitrary local vault names to BWS project IDs, and decides which operations may run automatically from a root-owned configuration.

Only the `bws` backend is currently implemented. Secret references remain provider-neutral: `secret://<backend>/<vault>/<id>`.

## Security model

The active policy lives at `/etc/secretctl/config.json`. On managed hosts, Nix generates the file in the immutable store and activates it under `/etc`; on other Linux hosts it must be installed as a root-owned mode `0644` file. Ordinary users and agents can read the policy but cannot change it without privileged activation or installation. `SECRETCTL_CONFIG` is intentionally unsupported because an override would bypass the policy boundary.

Each vault declares an arbitrary name, a backend, a remote project ID, and an allowlist containing any of `list`, `reveal`, `create`, `update`, and `delete`. Allowed operations run without root access or user presence. Unknown vaults and disallowed operations are rejected before the BWS token is loaded.

On macOS, `secretctl full-unlock` requires Touch ID, opens a mode `0600` Unix socket in a mode `0700` user directory, and blocks until Ctrl-C. While that foreground lease exists, other `secretctl` processes may perform every operation against every vault present in the root-owned config. Full unlock bypasses operation allowlists, not the configured vault map. Linux fails closed because the headless host has no equivalent user-presence check, so `full-unlock` is unavailable there.

On macOS, the BWS token is stored in the user's Keychain. Touch ID protects credential replacement, credential deletion, and the temporary full-access lease. On Linux, `systemd-creds` encrypts the token for the local machine and user, and the ciphertext is stored under `~/.config/secretctl/credentials` with mode `0600`. A same-user process can request decryption on either platform, so automatic operations allowed by policy do not require user presence.

This is a local policy boundary, not remote BWS isolation. Root access, compromise of the full token, or replacement of the trusted binary defeats it.

## Configuration

The config is fully data-driven. Vault names and project IDs have no meaning to the Go code:

```json
{
  "version": 2,
  "backends": {
    "bws": {
      "type": "bws",
      "organizationId": "ORGANIZATION_ID"
    }
  },
  "vaults": {
    "example": {
      "backend": "bws",
      "remoteId": "PROJECT_ID",
      "allow": ["list", "reveal", "create", "update", "delete"]
    }
  }
}
```

The m3-personal Nix host currently installs this policy:

| Vault | Automatically allowed |
| --- | --- |
| `agents` | `list`, `reveal`, `create`, `update`, `delete` |
| `k8s` | `list`, `create`, `update` |
| `personal` | `list`, `reveal`, `create` |

## Initial token setup

Create one BWS machine-account token with access to every project referenced by the config, then enter it through the hidden prompt:

```bash
secretctl auth set bws
secretctl auth status bws
```

The token is never accepted as a command-line argument. Setting or deleting it requires Touch ID on macOS. Linux reads hidden input directly from the controlling terminal but cannot provide the same user-presence guarantee.

## Raspberry Pi build

The Pi build targets static `linux/arm64`, so it does not depend on the target's C library. Build it from macOS with Go and Zig already available:

```bash
./build-linux-arm64.sh /tmp/secretctl-linux-arm64
```

The Linux credential backend requires systemd 256 or newer with `systemd-creds` and the `systemd-creds.socket` service. Debian 13 provides these components.

The Raspberry Pi policy contains only the `agents` vault, with all five operations allowed. Use a separate BWS machine token that has CRUD access only to the corresponding remote project. The remote project grant is the hard boundary: passwordless sudo on the Pi can bypass local files, but it cannot expand the BWS token's project scope.

## CLI

`list` fetches current BWS identifier metadata and filters it using the identifiers' project IDs. It never fetches secret values to construct the listing. `reveal` is the only command that writes a value to stdout.

```bash
# Root-owned policy and credential status
secretctl config show
secretctl auth status bws
secretctl status

# Metadata only
secretctl list
secretctl list --vault agents

# Mutations return metadata, never values
secretctl create --vault agents --key API_TOKEN --generate
secretctl create --vault k8s --key API_TOKEN --value-stdin
secretctl update --generate secret://bws/agents/SECRET_ID
secretctl delete secret://bws/agents/SECRET_ID

# Values must be streamed directly to their approved consumer
secretctl reveal secret://bws/personal/SECRET_ID | /absolute/path/to/verified-consumer
secretctl reveal --no-cache secret://bws/personal/SECRET_ID | /absolute/path/to/verified-consumer
```

There is no `get`, `refresh`, or `sync` command. Listing is always live and metadata-only.

## Reveal cache

`reveal` caches each value for five minutes in the platform credential store: macOS Keychain or user-and-machine-bound `systemd-creds` storage. Policy and reference validation run before cache lookup. Successful update and delete operations invalidate the matching entry.

Use `--no-cache` when freshness matters. It skips the cached entry, fetches the current value from BWS, and replaces the encrypted cache entry. The command still writes only the exact value to stdout.

## Full access lease

On macOS, when an operation is not allowed by the vault policy, `secretctl` directs the operator to run this in a separate terminal:

```bash
secretctl full-unlock
```

After Touch ID succeeds, leave that command running. Retry the denied operation from another terminal. Press Ctrl-C in the full-unlock terminal as soon as the work is complete.

On Linux, a denied operation stays denied until the root-owned policy is deliberately changed and reinstalled. `secretctl full-unlock` is unavailable.

## Adding a backend

Implement `backend.Factory` and `backend.Backend` in `internal/backend/<name>`, then register the factory in `loadRuntime`. The common policy layer validates the configured vault and operation before a backend receives credentials.
