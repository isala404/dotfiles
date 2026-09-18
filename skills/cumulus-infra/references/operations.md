# Operations

## Storage: directories on the node's root filesystem

There is no Longhorn, no replication, and no block-storage CSI. Every volume is a directory under the local-path provisioner on the node's RAID1 root. RAID1 survives one disk dying; it is not a backup and does not survive the machine.

Two classes, both `rancher.io/local-path`, both `WaitForFirstConsumer`:

| Class | Reclaim | For |
|---|---|---|
| `local-path` (default) | Delete | Rebuildable state. The registry uses it. |
| `local-path-retain` | Retain | Everything that matters: both databases, Toppics uploads, collector state. |

The retaining class exists because both application Kustomizations prune. Deleting a stateful PVC by accident would otherwise take the directory with it; with Retain the data stays as a Released PV and the cost is a manual rebind.

**Neither class allows volume expansion.** `allowVolumeExpansion` is false, so a PVC cannot be grown in place. Growing one means a new claim and a copy, so size stateful claims with room to spare.

Always set `storageClassName` explicitly, and remember the cluster overlay repatches it; see `gitops.md`.

## How backups actually work

Four CronJobs, all writing to the same S3-compatible bucket, all keeping fourteen days. Retention is enforced in the job rather than by a lifecycle rule, deliberately, so it lives in git.

| Job | Namespace | UTC | Destination prefix |
|---|---|---|---|
| `timescale-dump` | `timescale` | 02:30 | `dumps/timescale/<date>/` |
| `toppics-dump` | `toppics` | 02:45 | `dumps/toppics/<date>/` |
| `timescale-dump` | `timescale-dev` | 03:30 | `dumps/timescale-dev/<date>/` |
| `k3s-datastore-backup` | `k3s-backup` | 04:30 | `control-plane/polaris-k3s/<date>/state.db.gz` |

The schedules are staggered so they never share the node's disk or the same connection to the bucket.

These are logical dumps on a nightly schedule. **There is no WAL archiving, no snapshot job, and nothing kept locally.** The worst-case recovery point is roughly 24 hours. State that plainly when someone asks what an outage costs; do not imply finer granularity than exists.

Two details that matter:

- **The Toppics dump is a pair.** A SQLite `VACUUM INTO` file and `uploads.tar.gz` from the same dated prefix. Restore and verify them as a unit or the database describes files that are not there.
- **The control-plane job depends on secrets encryption.** k3s has no snapshot command for a SQLite datastore, so the job takes a consistent copy through the SQLite backup API, gzips it and ships it off-host. Without `secrets-encryption: true`, `state.db` is a plaintext copy of every Secret in the cluster and this job would upload that nightly. Do not enable it on a host where `k3s secrets-encrypt status` reports Disabled. The decryption key stays in `/var/lib/rancher/k3s/server/cred/encryption-config.json` and is deliberately not in the backup, which also means a datastore restore needs that file from somewhere else.

```bash
kubectl get cronjob -A
kubectl get job -A --sort-by='.metadata.creationTimestamp' | tail -10
```

A stateful workload with no dump job is silently unprotected. Check this whenever you add one.

## Restoring

**One database.** Never restore over a live one.

1. Pick the dated prefix and pull the archive set, globals included.
2. Scale the consuming workloads to zero.
3. `createdb -T template0`, then create every extension **at the version the dump came from**. This is the trap: the Postgres image installs newer extension versions into `template1`, a plain `createdb` inherits them, and `CREATE EXTENSION IF NOT EXISTS ... VERSION '<old>'` then silently does nothing. It surfaces much later as a catalog version mismatch or a missing hypertable id in the middle of a COPY.
4. For TimescaleDB, run `timescaledb_pre_restore()` before `pg_restore` and `timescaledb_post_restore()` after, and do not use parallel restore workers.
5. Verify by row count per table on both sides before anything reconnects.

Globals deliberately omit password hashes, so application role passwords come back from the secret store. The db-init Jobs do exactly that on their first run, which is why the database layer is a separate Kustomization the applications depend on: those Jobs are idempotent against a finished restore and destructive against a half-finished one.

**One file volume.** Scale to zero, restore beside the live directory, swap, verify, then delete. With the retaining class a Released PV can also simply be rebound.

**The whole node.** This is the case the design is built around, and it works because nothing durable lives only on the box:

1. Provision a fresh server and install k3s with the same config file.
2. Bootstrap Flux against the deployment branch. It rebuilds every namespace, workload, and policy from git.
3. ESO re-pulls every secret from the provider because none of them were on the node.
4. Restore the databases and file volumes from the nightly dumps.
5. DNS and certificates re-provision themselves once the Gateway is up, except the apex records; see `platform.md`.

The recovery point is the last successful dump, not the moment of failure. Rehearse a restore occasionally, because an untested backup is a guess.

## k3s upgrades

Single node, so every upgrade is downtime. Say so before starting.

The server is configured by file, not by flags: `/etc/rancher/k3s/config.yaml`, whose reviewed source is checked into the cluster directory as `k3s-server-config.yaml`. That is a real improvement over the old flag soup, but it means **the config file is load-bearing and must not drift from the repo copy**. It disables flannel, kube-proxy, the network policy controller, the embedded Helm controller, Traefik and ServiceLB, because Cilium owns all of that; dropping one of those lines re-enables a component Cilium already provides and breaks networking.

Pin the version deliberately. Cilium documents which Kubernetes minors it supports, and k3s moves faster than that guarantee. Rollback is the same installer with the previous version; the datastore under `/var/lib/rancher/k3s/server/db/` is preserved. Afterwards, verify with a real HTTPS request from outside the cluster, not just pod status.

## Component upgrades

Everything infra is a HelmRelease. Bump `spec.chart.spec.version` and push; Flux rolls back on its own where `spec.upgrade.remediation.retries` is set.

Risk order, highest first:

- **Cilium:** single minor jumps only, and check Gateway API CRD compatibility. It's CNI and ingress at once, so a bad upgrade takes networking *and* routing down together. Verify both pod egress and gateway routing after.
- **cert-manager / ESO:** watch for CRD API version changes.
- **external-dns:** stateless watcher, low risk, but it holds record ownership; see `platform.md`.

The helm-controller uses server-side apply, and container `env` is a list keyed by name. A patch that adds a variable a chart preset already sets is rejected as a duplicate rather than merged. That is a real failure mode when overriding collector or agent values.

Rolling back an *application* is different: revert the automated commit that bumped the image tag, or pin the previous tag by hand. Note that the registry's nightly GC keeps only the two most recent tags per pattern, so rolling back far enough means rebuilding.

## Hardening invariants

Workloads run non-root with a read-only root filesystem, no privilege escalation, all capabilities dropped, and a default-deny NetworkPolicy. Secrets come from the external store, never git or ConfigMaps. Secret values are encrypted at rest in the datastore. CI authenticates by OIDC, so there are no long-lived registry credentials to leak.

Never: expose the API server publicly, disable a network policy to debug, grant an app cluster-admin, or mount the Docker socket or host filesystem.

## Health check

```bash
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get kustomization,helmrelease -A
kubectl get externalsecret,certificate -A
kubectl get pvc -A
kubectl get gateway -A -o wide
```
