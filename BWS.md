# Bitwarden Secrets Manager (BWS)

Credentials (AWS keys, kubeconfig, SSH keys, GPG keys) are stored in BWS and fetched on demand. Access is gated behind Touch ID with password fallback. Responses are cached locally to avoid repeated API calls and prompts.

## How it works

```
tool request (aws, kubectl, bws)
  → check response cache (~/.cache/bws/, 1hr TTL)
    → HIT: return cached response, done
    → MISS:
      → check Touch ID cache (5min TTL)
        → HIT: skip prompt
        → MISS: Touch ID prompt (password fallback)
      → read BWS token from macOS Keychain
      → call BWS API
      → cache response
      → return
```

## Components

| File | Purpose |
|------|---------|
| `bin/keychain-bio.swift` | Touch ID gated Keychain access. Compiled during `darwin-rebuild switch` |
| `bin/bws/aws-credential-helper.sh` | AWS `credential_process` that fetches keys from BWS |
| `bin/bws/kube-credential-helper.sh` | kubectl exec credential plugin that fetches certs from BWS |

The fish shell has a `bws` wrapper function that injects the token from Keychain on every call.

## Initial setup

### 1. Store the BWS access token in Keychain

```bash
keychain-bio store bws-access-token '<your-bws-access-token>'
```

This only needs to happen once per machine.

### 2. Verify

```bash
bws secret list
```

## Storing secrets

### AWS credentials

```bash
bws secret create <name> 'AccessKeyId=AKIA... SecretAccessKey=...' <project-id>
```

Then add to `~/.aws/config`:

```ini
[profile myprofile]
region = us-east-1
credential_process = /Users/<you>/.aws/bws-credential-helper.sh <secret-id>
```

Remove any matching entry from `~/.aws/credentials` (or leave it empty).

### Kubeconfig (per-context)

Export the current context:

```bash
kubectl config view --minify --flatten -o json
```

Store it:

```bash
bws secret create <cluster>-kubeconfig '<json-output>' <project-id>
```

Update the user entry in `~/.kube/config`:

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

Remove `client-certificate-data` and `client-key-data` from that user. Cluster and context sections stay as-is.

### SSH keys

```bash
bws secret create <name> -- "$(cat ~/.ssh/id_ed25519)" <project-id>
bws secret create <name>-pub -- "$(cat ~/.ssh/id_ed25519.pub)" <project-id>
```

### GPG keys

```bash
PRIVATE=$(gpg --armor --export-secret-keys <email>)
PUBLIC=$(gpg --armor --export <email>)

bws secret create <name> -- "$PRIVATE" <project-id>
bws secret create <name>-pub -- "$PUBLIC" <project-id>
```

Values starting with `-----BEGIN` confuse the bws CLI parser. Use `--` before the value.

## Restoring on a new machine

### BWS token

Get access token from Bitwarden web vault:

```bash
keychain-bio store bws-access-token '<token>'
```

### SSH key

```bash
bws secret get <secret-id> -o json | python3 -c "
import sys, json
print(json.load(sys.stdin)['value'])
" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

### GPG key

```bash
bws secret get <secret-id> -o json | python3 -c "
import sys, json
print(json.load(sys.stdin)['value'])
" | gpg --import
```

## Useful commands

```bash
bws project list           # list projects with IDs
bws secret list            # list all secrets with IDs
```
