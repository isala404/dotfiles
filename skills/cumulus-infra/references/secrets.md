# Cluster secrets

This reference covers Kubernetes-side secret handling in Cumulus. For BWS, Bitwarden, or retrieving, creating, and rotating provider credentials, use the `bws-secrets` skill first. That skill owns the credential workflow; do not reproduce it here.

## The rule: inspect metadata, not values

Never display a cluster-managed secret value. Use key names, counts, lengths, status, and exit codes to diagnose problems. If the operator explicitly provides a dev or temporary value, pass it only to the requested command and never echo it.

Do not run commands that return secret payloads, such as:

```
kubectl get secret X -o yaml
kubectl get secret X -o json
kubectl get secret X -o jsonpath='{.data.KEY}'
cat .env
printenv
```

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

## Creating a temporary Kubernetes secret

```bash
kubectl create secret generic <name> -n <ns> --from-literal=KEY="$VALUE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic <name> -n <ns> --from-env-file=.env \
  --dry-run=client -o yaml | kubectl apply -f -
```

For a provider-backed secret, update the provider through `bws-secrets`, then force the sync. Reloader restarts the pods on its own:

```bash
kubectl annotate externalsecret <name> -n <ns> force-sync=$(date +%s) --overwrite
```

## How provider-backed secrets reach pods

```
Configured secret provider -> sdk-server (external-secrets ns, mTLS) -> ClusterSecretStore
  -> ExternalSecret (app ns) -> Secret -> Reloader rolls the pods
```

- The store is cluster-scoped; any namespace can reference it.
- `creationPolicy: Owner` means deleting the ExternalSecret deletes the Secret, and hand-edits are overwritten on the next sync. Never patch an Owner-managed Secret to fix something.
- The 5m refresh is a no-op when the value is unchanged, so there are no spurious restarts.
- Each app gets its own provider-backed entries even when two apps hold the same value.
- SDK server down means nothing syncs, but existing Secrets stay intact, so the symptom is staleness, not outage.

## When sync fails

| Message | Cause |
|---------|-------|
| `secret does not exist` | Wrong provider identifier |
| `could not get provider client` | SDK server down |
| `could not get secret data` | Provider authentication or lookup failed |
| `store not found` | ClusterSecretStore unhealthy |

```bash
kubectl get externalsecret -A | grep -v SecretSynced
kubectl get externalsecret <name> -n <ns> -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}'
```

If a pod starts but reads an empty variable, it's a key-name mismatch, not a sync failure. Compare the deployment's `secretKeyRef.key` values against the secret's key names.

## If a cluster credential leaks

Stop, say so immediately, and treat it as compromised regardless of how briefly it appeared. Use `bws-secrets` for provider-side rotation, force-sync the ExternalSecret, and start a fresh session. A leaked production credential that goes unmentioned is far worse than the leak.
