# Operations

## Storage: one replica on one box

Longhorn runs at `defaultReplicaCount: 1`, with data under `/var/lib/longhorn` on the node's own disk. There is no second replica and no second node, so **the off-box backup is the only real redundancy.** Never delete a production volume without explicit approval.

Two StorageClasses are both marked default, k3s's `local-path` and `longhorn`, so a PVC that names neither is a coin flip. Always set `storageClassName`; run `kubectl get sc` to see what exists. A third class, backed by the host provider's block-storage CSI driver, is deliberately not default and exists for volumes that should outlive the node.

Volumes expand online, so start small:

```bash
kubectl patch pvc <name> -n <ns> -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

## How backups actually work

Two RecurringJobs in `infrastructure/core/longhorn/recurring-jobs.yaml`, both `task: backup`, both writing to S3-compatible object storage:

| Job | Cron in the manifest | Fires at | Retains |
|-----|---------------------|----------|---------|
| `daily-backup` | `30 7 * * *` | 02:00 UTC daily | 7 |
| `weekly-backup` | `30 8 * * 0` | 03:00 UTC Sunday | 4 |

The cron strings are offset by the cluster's UTC+05:30 locale, so they don't read as the UTC times they produce. Check an actual `Backup` timestamp before concluding a schedule is wrong.

**There is no snapshot job.** Nothing runs hourly, and nothing is kept locally on purpose. So the worst-case recovery point is roughly 24 hours. Whatever happened since 02:00 UTC is gone with the disk. State that plainly when someone asks what an outage costs; don't imply finer granularity than exists.

The target and its credentials are set in two places that must agree: `backupTarget` / `backupTargetCredentialSecret` in the Helm values, and a `BackupTarget` resource with the matching `backupTargetURL` and `credentialSecret`. The credential secret itself arrives through an ExternalSecret.

Longhorn reads the target at startup, so **an empty `backupTargetURL` almost always means the credentials hadn't synced when Longhorn came up**. Check the ExternalSecret first, then restart the manager rather than editing settings by hand.

RecurringJobs only act on volumes that opt in, by label on the volume or by belonging to a job group. A job can therefore be perfectly healthy and be backing up nothing. Verify coverage rather than assuming it:

```bash
kubectl get recurringjob -n longhorn
kubectl get volume.longhorn.io -n longhorn -o custom-columns=\
NAME:.metadata.name,LABELS:.metadata.labels
kubectl get backup -n longhorn --sort-by='.metadata.creationTimestamp' | tail -10
kubectl get backupvolume -n longhorn
kubectl get backuptarget default -n longhorn -o custom-columns=URL:.spec.backupTargetURL,AVAIL:.status.available
```

A new volume with no job label is silently unprotected. Check this whenever you add a stateful app.

## Restoring

**One volume.** Never restore over a live volume. The restore is a new volume, and the old one is your rollback.

1. Find the backup: `kubectl get backup -n longhorn --sort-by='.metadata.creationTimestamp'`.
2. Scale the workload to zero so nothing writes during the swap.
3. Create a **new** volume from the backup, then a PV/PVC bound to it.
4. Repoint the deployment at the new PVC and scale back up.
5. Verify the data is actually there and current before deleting anything.

If the PVC was deleted but the Longhorn volume survives, you can skip the restore and just bind a fresh PVC to the existing volume. If both are gone, it's a restore from backup.

**The whole node.** This is the case the design is built around, and it works because nothing durable lives only on the box:

1. Provision a fresh server, install k3s with the same disable flags.
2. Bootstrap Flux against the deployment branch. It rebuilds every namespace, workload, and policy from git.
3. ESO re-pulls every secret from the configured provider because none of them were on the node.
4. Point Longhorn at the same backup target and restore volumes from object storage.
5. DNS and certificates re-provision themselves once the Gateway is up.

The recovery point is the last successful backup, not the moment of failure. Rehearse a single-volume restore occasionally because an untested backup is a guess.

## k3s upgrades

Single node, so every upgrade is downtime. Say so before starting.

The operator runs the installer over SSH. **Every flag on the current unit must be repeated**, because dropping one re-enables a component Cilium already provides and breaks networking, and the installer does not carry the old arguments forward. Read them off the running server rather than retyping a remembered list:

```bash
sudo sed -n '/ExecStart=/,/^$/p' /etc/systemd/system/k3s.service
```

Expect more than the obvious four: alongside the disables for the flannel backend, the network policy controller, traefik, and servicelb, there is a separate flag disabling kube-proxy, plus TLS SANs and kubelet and controller tuning that are just as load-bearing.

Rollback is the same installer with the previous version; the datastore under `/var/lib/rancher/k3s/server/db/` is preserved. Afterwards, verify with a real HTTPS request from outside the cluster, not just pod status.

## Component upgrades

Everything infra is a HelmRelease. Bump `spec.chart.spec.version` and push; Flux rolls back on its own where `spec.upgrade.remediation.retries` is set.

Risk order, highest first:

- **Cilium:** single minor jumps only, and check Gateway API CRD compatibility. It's CNI and ingress at once, so a bad upgrade takes networking *and* routing down together. Verify both pod egress and gateway routing after.
- **Longhorn:** data plane. Some versions can't be skipped; check the upgrade path.
- **cert-manager / ESO:** watch for CRD API version changes.
- **external-dns, Reloader:** stateless watchers, low risk.

Rolling back an *application* is different: revert the automated commit that bumped the image tag, or pin the previous tag by hand. Note that the registry's nightly GC keeps only the two most recent tags per pattern, so rolling back far enough means rebuilding.

## Hardening invariants

Workloads run non-root with a read-only root filesystem, no privilege escalation, all capabilities dropped, and a default-deny NetworkPolicy. Secrets come from the external store, never git or ConfigMaps. CI authenticates by OIDC, so there are no long-lived registry credentials to leak.

Never: expose the API server publicly, disable a network policy to debug, grant an app cluster-admin, or mount the Docker socket or host filesystem.

## Health check

```bash
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get kustomization,helmrelease -n flux-system
kubectl get externalsecret,certificate -A
kubectl get volume.longhorn.io -n longhorn
kubectl get gateway -A
```
