# GitOps repository

## The cluster does not own its manifests

**`clusters/polaris-k3s/` holds no application manifests.** The shared `apps/` and `infrastructure/` trees are the real source, and the cluster directory is a set of thin Kustomizations that reference those paths and patch out whatever this host does not run. So a change to an application belongs in `apps/`, and a change to the cluster's *view* of it belongs in `clusters/polaris-k3s/`.

The split is left over from a migration off an earlier host and is worth collapsing one day, but until then the indirection is real and you have to edit the right side of it.

```
apps/base/<app>/       namespace, deployment, service, network-policy,
                       image-automation, kustomization
apps/prod/<app>/       kustomization (namespace: <app>), *.externalsecret.yaml,
                       httproute.yaml, pvc.yaml
apps/dev/<app>/        kustomization (namespace: <app>-dev), dev secret references,
                       deployment-patch.yaml, network-policy-patch.yaml

infrastructure/configs/  Gateway, ClusterIssuers, SecretStore, namespaces,
                         provider-token ExternalSecrets
infrastructure/utils/    external-dns, registry, OIDC broker, registry-cleaner

clusters/polaris-k3s/foundation/  Cilium, cert-manager, ESO,
                                  Gateway API CRDs, StorageClass
clusters/polaris-k3s/infra/       overlays over infrastructure/*
clusters/polaris-k3s/apps/        overlays over apps/prod and apps/dev, plus a
                                  separate `data` layer for the databases
```

The overlays are worth reading before you touch anything, because they carry the reasons. What they still do is narrow: a handful of `$patch: delete` entries removing an unused ClusterSecretStore and the pieces of external-dns and registry-cleaner that are redefined in their own Kustomizations. Storage classes are written directly in `apps/` now, so a PVC lands on exactly the class its own manifest names.

## Reconcile order

```
flux-system
  └─ polaris-gateway-api
       └─ polaris-platform            Cilium, cert-manager
            ├─ polaris-storage        the retaining StorageClass
            └─ polaris-bitwarden-tls
                 └─ polaris-external-secrets
                      └─ polaris-bitwarden
                           └─ polaris-infra-configs
                                └─ polaris-infra-utils   (also needs polaris-storage)
                                     ├─ polaris-external-dns
                                     ├─ polaris-k3s-backup
                                     ├─ polaris-registry-cleaner   (suspended)
                                     └─ polaris-data
                                          └─ polaris-prod-apps
                                               └─ polaris-dev-apps
```

A new infra component placed in the wrong layer races its dependencies and fails on first apply. A failure early in the chain stalls everything after it, so the app that looks broken is often innocent.

`polaris-data` exists to create a window: it brings up the two Timescale servers, and `polaris-prod-apps` depends on it, so a restore can finish before any db-init Job resets role passwords against a half-restored server.

`polaris-registry-cleaner` is suspended in git. Unsuspending it is a commit, not a kubectl patch, and it prunes the registry down to the two newest tags per pattern as soon as it runs.

## Forcing a reconcile without the flux CLI

There is no `flux` binary. Annotate instead:

```bash
kubectl annotate --overwrite gitrepository/flux-system -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

**Annotate the root only, then wait.** Annotating a Kustomization and its parent at the same instant makes the child observe the parent as `Ready=Unknown` and report `dependency ... is not ready` for another full retry interval. Each level settles about 25 to 30 seconds after the one above it, so the whole chain is roughly four minutes. A stale `dependency not ready` message on a leaf whose parent is already True means you are looking at the previous attempt, not a failure.

Pushes land on their own within the reconcile interval, an hour for the infra layers and ten minutes for the app layers.

Do not quiesce anything by patching `suspend: true` with kubectl. Kustomization objects are themselves reconciled from git, so the field is reset on the next parent pass and everything restarts about ten minutes later, which reads as a mystery. Either scale the `flux-system` controller Deployments to zero or commit the suspension.

## Image automation

Three resources per app in `apps/base/<app>/image-automation.yaml`: an ImageRepository scanning the registry path, an ImagePolicy selecting a tag, and an ImageUpdateAutomation committing the result back to the deployment branch.

**Use `image.toolkit.fluxcd.io/v1`.** The current controllers do not serve `v1beta2`; a manifest left on the beta API fails at apply time and takes its whole Kustomization's dry run with it. Nothing in the repo should go back to a beta API.

Policies filter `^prod-(?P<number>\d+)$` and order `numerical`, which pairs with CI tagging both prefixes by `github.run_id`; see `ci-cd.md`. A dev overlay uses the same policy against `^dev-(?P<number>\d+)$`; both overlays are automated wherever a dev copy exists.

**The filter has to match what the app's CI actually emits.** A workflow tagging releases with the git tag (`prod-v1.2.0`) matches a numeric filter zero times, and the symptom is silence rather than an error. Check the emitted scheme first whenever an image "isn't updating".

The image line must carry the setter comment or nothing updates and, again, nothing complains:

```yaml
image: <registry>/<org>/<app>:prod-18 # {"$imagepolicy": "<namespace>:<app>"}
```

## Local conventions in the manifests

Only the parts that are conventions here, not Kubernetes generally:

- **ExternalSecret:** `refreshInterval: 5m`, `kind: ClusterSecretStore`, `creationPolicy: Owner`, target named `<app>-secrets`, consumed via `envFrom`.
- **HTTPRoute:** `parentRefs` points at the Gateway in the `default` namespace and must set the `sectionName` of the listener covering that hostname. Wildcard and apex are separate listeners.
- **NetworkPolicy:** default-deny on every workload, so egress needs explicit rules. DNS to kube-system (53 UDP *and* TCP) is required by everything; then 5432 to the database namespace, and 443 to `0.0.0.0/0` with RFC1918 excluded for outbound HTTPS.
- **PVC:** always name a `storageClassName`, and expect the cluster overlay to repatch it.

## Shared database

Postgres is shared, and there are two servers. Each app gets its own database and user, bootstrapped by an init Job; superuser credentials are used only by that Job, never by the app. So a database-backed app carries two secrets: its own connection credentials, and a `db-init` secret holding the superuser password, the app password, and the host.

The two servers intentionally contain databases with the same names, and at least one production workload points at the server labelled dev through an ExternalName Service. Never decide which server a workload uses from the namespace label; read the Service.

## Adding an app

Start with the base manifests, prod overlay, ExternalSecrets, and registry pull secret. Then handle the three misses that cost the most time:

1. Add it to `apps/prod/kustomization.yaml` **and** to `clusters/polaris-k3s/apps/prod/kustomization.yaml`, which lists directories individually rather than referencing the parent. Forget either and nothing happens, silently.
2. If it uses the database, add an ingress allow for the new namespace to the **database's** NetworkPolicy. Forget this and you get a hang with no useful log line.
3. If it is stateful, name a StorageClass in the PVC. The default class deletes the directory along with the claim; see `operations.md` for which class to pick.
