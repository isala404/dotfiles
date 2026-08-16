# Secrets

## The rule: plumbing is fine, printing is not

You may *move* a secret into an env var, a pipe, a `bws` update, or a `kubectl create secret`. You may not *display* one. The distinction is where the value ends up: a variable and a pipe are fine, stdout and your reply are not.

So: no bare command whose output is a value. Redirect to `/dev/null`, project out a non-secret field with `jq`, or capture into a shell variable. Verify by exit code, not by looking.

Two tiers, and they are not the same:

- **This cluster's secrets:** production, infrastructure, and anything already in Bitwarden. Never surfaced, no exceptions. Don't read them to check them; use the key-name and length probes below. If you need a value you don't have, ask.
- **Dev and temporary secrets the operator hands you:** a throwaway API key, a local `.env`, or a test credential. You may work with these directly when asked: set them, test with them, put them in a dev secret. Still don't echo them back gratuitously because the transcript persists and gets replayed into future context. This is a normal task, not a violation.

When the operator gives explicit permission for a specific value, that permission covers *that* value for *that* task. It does not generalise to the vault.

## Never run bare

```
kubectl get secret X -o yaml / -o json / -o jsonpath='{.data.KEY}'
kubectl describe secret X
bws secret get <id>          # prints the value
bws secret list <project>    # prints every value
cat .env    printenv
```

Each has a piped equivalent below.

## Inspecting without reading

```bash
# key names only
kubectl get secret <name> -n <ns> -o go-template='{{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}'
# key count, and one key's byte length, enough to spot a truncated or empty value
kubectl get secret <name> -n <ns> -o go-template='{{len .data}}'
kubectl get secret <name> -n <ns> -o go-template='{{index .data "KEY" | len}}'
# env var names inside a running pod
kubectl exec deploy/<name> -n <ns> -- env | cut -d= -f1 | sort
```

`diff` two key-name listings to compare prod against dev, or against a local file's keys:
`grep -v '^#' .env | grep = | cut -d= -f1 | sort`.

## Reading a value into a variable

Everything goes through the biometric-unlocked keychain, which holds the Bitwarden access token. The token itself is a secret. It is only ever a subshell substitution, never exported to your shell and never printed:

```bash
VAL=$(BWS_ACCESS_TOKEN=$(keychain-bio get bws-access-token) \
      bws secret get <id> 2>/dev/null | jq -r '.value')
```

`$VAL` now holds it. Use it, then `unset VAL`. Do not echo it to confirm it worked. Check `[ -n "$VAL" ]` or the exit code.

Feeding it somewhere:

```bash
# into a one-shot command's environment
SECRET="$VAL" python3 -c "import os; use(os.environ['SECRET'])"

# into a Kubernetes secret
kubectl create secret generic <name> -n <ns> --from-literal=KEY="$VAL" \
  --dry-run=client -o yaml | kubectl apply -f -

# from a file, without ever opening it
kubectl create secret generic <name> -n <ns> --from-env-file=.env \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Writing to Bitwarden

`edit` echoes the secret back on success and `create` returns it inside the JSON, so both need suppressing:

```bash
BWS_ACCESS_TOKEN=$(keychain-bio get bws-access-token) \
  bws secret edit <id> --value "$VAL" > /dev/null

BWS_ACCESS_TOKEN=$(keychain-bio get bws-access-token) \
  bws secret create "k8s/<ns>/<secret>/<KEY>" "$VAL" <project-id> | jq -r '.id'
```

Project ID is **positional** in both `secret list` and `secret create`. Passing `--project-id` exits 2.

Rotating in one chain, so the value never lands anywhere durable:

```bash
NEW=$(<create-credential> 2>/dev/null | jq -r '.field') \
  && BWS_ACCESS_TOKEN=$(keychain-bio get bws-access-token) \
     bws secret edit <id> --value "$NEW" > /dev/null \
  && unset NEW && echo ok
```

Then force the sync. Reloader restarts the pods on its own:

```bash
kubectl annotate externalsecret <name> -n <ns> force-sync=$(date +%s) --overwrite
```

Any CLI that prints a credential once on creation, including cloud access keys, API tokens, and database users, must be captured this way. Run bare, it's gone into the transcript and needs rotating.

## Finding an ID

Don't enumerate the vault into your own context. Ask the operator to run the listing filtered down to IDs and names:

```
! bws secret list <project-id> | python3 -c "import sys,json; [print(s['id'], s['key']) for s in json.load(sys.stdin)]"
```

Naming convention is `k8s/<namespace>/<secret-name>/<key>`, so the name usually tells you which one you want.

## How they reach pods

```
Bitwarden -> sdk-server (external-secrets ns, mTLS) -> ClusterSecretStore
  -> ExternalSecret (app ns) -> Secret -> Reloader rolls the pods
```

- The store is cluster-scoped; any namespace can reference it. The cluster holds exactly one access token.
- `creationPolicy: Owner` means deleting the ExternalSecret deletes the Secret, and hand-edits are overwritten on the next sync. Never patch an Owner-managed Secret to fix something.
- The 5m refresh is a no-op when the value is unchanged, so there are no spurious restarts.
- Each app gets its own vault entries even when two apps hold the same value.
- SDK server down means nothing syncs, but existing Secrets stay intact, so the symptom is staleness, not outage.

## When sync fails

| Message | Cause |
|---------|-------|
| `secret does not exist` | Wrong ID |
| `could not get provider client` | SDK server down |
| `could not get secret data` | Access token expired |
| `store not found` | ClusterSecretStore unhealthy |

```bash
kubectl get externalsecret -A | grep -v SecretSynced
kubectl get externalsecret <name> -n <ns> -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}'
```

If a pod starts but reads an empty variable, it's a key-name mismatch, not a sync failure. Compare the deployment's `secretKeyRef.key` values against the secret's key names.

## If you leak one

Stop, say so immediately, and treat it as compromised regardless of how briefly it appeared. Rotate in Bitwarden, force-sync, start a fresh session. A leaked prod credential that goes unmentioned is far worse than the leak.
