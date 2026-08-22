# Troubleshooting

Only the failures whose cause is specific to this setup. For ordinary pod debugging, use your own judgement: logs, describe, events.

## Image isn't updating

The most common non-obvious failure. Three stages, and the break is always at exactly one:

```bash
kubectl get imagerepository <app> -n <ns> -o jsonpath='{.status.lastScanResult}'   # sees the tag?
kubectl get imagepolicy <app> -n <ns> -o jsonpath='{.status.latestImage}'          # selects it?
kubectl get imageupdateautomation <app> -n <ns> -o jsonpath='{.status.lastAutomationRunTime}'
```

By frequency: the tag doesn't match the policy's filter, the `$imagepolicy` setter comment is missing from the image line (this fails **silently** with no error), the ImageRepository can't reach the registry, or the automation can't push to the deployment branch.

## Rollback to an old tag fails to pull

Expected. The registry's GC prunes nightly and keeps only the two most recent tags per pattern, so old tags genuinely stop existing. Rebuild rather than hunting for the image.

## `dig` shows the wrong address

Records are proxied by the CDN, so DNS never returns the node. Not a fault. New routes also need a minute or two for external-dns to publish before anything resolves at all.

## A LoadBalancer Service stays Pending forever

Expected: LB-IPAM has no pools and there is no cloud load balancer, so nothing can ever assign an address. Leave it Pending and route through the Gateway with an HTTPRoute instead. Do not "fix" it by adding a pool holding the node IP — Cilium would claim that IP as a service VIP and its datapath would drop every non-service port on it, SSH and DNS included.

## HTTPRoute not accepted

Nearly always the `sectionName`: it must name a listener whose hostname pattern actually covers the route's hostname. Wildcard and apex are separate listeners, so an apex hostname on a wildcard listener silently fails to attach.

```bash
kubectl get httproute <name> -n <ns> -o jsonpath='{.status.parents[0].conditions}'
```

## Pod can't reach the database or an external host

Default-deny is on everywhere, so this is a missing egress rule until proven otherwise. Never remove the policy to prove it. Add the specific allow and test from inside the pod.

If the app is new, check the **database's** NetworkPolicy too: it needs an ingress allow for the new namespace, and that omission looks like a hang, not a rejection.

## Dev migrations fail after migration history was rewritten

Dev database history is disposable when the operator has deliberately replaced, squashed, or edited existing test migrations and asks you to get the migration working. In that case, prefer a clean database over repairing the stale migration history: confirm the exact environment and logical database, explain that its data will be lost, get confirmation for the destructive operation, then drop and recreate only that database and let the migrator rebuild it from scratch.

Never drop the database server or instance, its storage, another logical database, or anything outside dev. Stop if the target is ambiguous or shared, or if you cannot independently prove that it is the intended dev database.

## Certificates stop renewing

Suspect the DNS provider API token first. It's synced by ExternalSecret into both cert-manager and external-dns, so both break together. Otherwise suspect propagation lag (5 to 10 min) or an ACME rate limit from retrying. Deleting the Certificate forces reissue, but only do that once you know the cause or you'll spend the remaining rate limit.

## Volume shows degraded after a restart

Single replica rebuilding. Wait. Backup failures, separately, are usually the object-storage credentials. Check that ExternalSecret before anything in Longhorn.

## kubectl auth fails

The exec plugin (`~/.kube/bws-credential-helper.sh`) pulls the kubeconfig from the secret store on every call, so this is a secret-store problem, not an expiry. Run the helper's underlying `secretctl` check from the `bws-secrets` skill: a policy denial, a missing backend token, or a stale cached value all surface here. `secretctl reveal --no-cache` past a stale cache; anything else needs the operator.

## Flux stopped reconciling

```bash
kubectl get kustomization <name> -n flux-system -o jsonpath='{.status.conditions[0].message}'
```

Remember the dependency chain. A failure in an earlier layer stalls everything after it, so the app that looks broken is often innocent. Check `infra-core` first.
