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

## Every public hostname hangs, or Envoy answers 503 for everything

Cilium 1.20.2 accepts `enableXTSocketFallback: false`, writes `enable-xt-socket-fallback=false` into `cilium-config`, and then installs the rule anyway. Upstream calls it fixed in 1.20.3, which is not released yet. The rule is in the `mangle` table:

```bash
iptables -t mangle -S CILIUM_PRE_mangle
```

It marks `0x200` on any packet matching a transparent socket, which routes it via `ip rule 9` to table 2004 where nothing delivers it. That kills both halves of the host-network Gateway: the ACK that completes an external TCP handshake to the 443 listener, and the SYN-ACK coming back from a pod to Envoy's transparent upstream socket. So the symptom is public TLS connections that hang with no response at all, and, if a handshake does get through, Envoy 503s with `upstream_cx_connect_timeout` climbing in the admin socket's stats. The node can still reach its own Gateway over loopback, which makes it look like a routing or DNS problem from outside.

The host firewall carries a `gateway_mark_fix` chain that clears the mark, which is what the ignored option was supposed to do. If this comes back, check the chain is still loaded rather than touching Cilium:

```bash
nft list chain inet cumulus_host gateway_mark_fix
```

The counter on that rule should be climbing. Deleting Cilium's mangle rule by hand also works, but the agent reinstalls it on restart and on proxy resyncs, so it is a diagnostic and not a fix.

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

## A PVC stays Pending

The local-path classes are `WaitForFirstConsumer`, so a claim with no pod scheduled against it is Pending by design and not a fault. A claim that stays Pending *with* a pod pending too is usually a class name that does not exist.

A PVC you cannot grow is also expected: neither class sets `allowVolumeExpansion`, so the only way to enlarge a volume is dump, delete, recreate larger, restore.

## A rotated secret changed nothing

There is no Reloader here. The Secret syncs and the running pods keep the old value until you restart them yourself. See `secrets.md`.

## A nightly backup did not appear in object storage

Check the CronJob's last Job and its pod logs, then the object-storage credential ExternalSecret. Retention is enforced inside the job, so a job that fails halfway can leave a partial prefix behind; look at what is actually in the bucket before trusting the date directory.

## kubectl cannot reach the cluster

Check `tailscale status` first. The API is only reachable over the tailnet, so a logged-out or expired Tailscale session times out rather than failing cleanly, and the timeout looks identical to the cluster being down.

Then check `kubectl config current-context`. Other contexts on this machine point at unrelated clusters.

A TLS error naming a hostname rather than a timeout means the certificate has no SAN for the address you used. The SAN list lives in `clusters/polaris-k3s/k3s-server-config.yaml`, and k3s only reissues the serving certificate when the old one is deleted, so adding a name there needs `infra/hetzner/apply-k3s-config.sh`, not a restart.

The kubeconfig holds a client certificate and does not expire on its own, so auth is rarely the problem.

## Flux stopped reconciling

```bash
kubectl get kustomization <name> -n flux-system -o jsonpath='{.status.conditions[0].message}'
```

Remember the dependency chain in `gitops.md`. A failure in an early layer stalls everything after it, so the app that looks broken is usually innocent: walk up to the first Kustomization that is not Ready and fix that one.

A `dependency ... is not ready` message whose parent is already Ready is stale. Each level settles roughly half a minute after the one above it, so read the message's age before acting on it, and never chase it by annotating children.
