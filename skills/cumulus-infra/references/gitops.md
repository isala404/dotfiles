# GitOps repository

## Layout

Base holds everything environment-neutral; overlays hold only what differs.

```
apps/base/<app>/       namespace, deployment, service, network-policy,
                       image-automation, kustomization
apps/prod/<app>/       kustomization (namespace: <app>), *.externalsecret.yaml,
                       httproute.yaml, pvc.yaml
apps/dev/<app>/        kustomization (namespace: <app>-dev), dev secret references,
                       deployment-patch.yaml, network-policy-patch.yaml

infrastructure/core/     CNI, cert-manager, ESO, Longhorn, block-storage CSI, Reloader
infrastructure/configs/  Gateway, ClusterIssuers, SecretStore, namespaces,
                         provider-token ExternalSecrets
infrastructure/utils/    external-dns, registry, OIDC broker
```

Reconcile order is `infra-core` -> `infra-configs` -> `infra-utils` -> `apps`. A new infra component placed in the wrong layer races its dependencies and fails on first apply. A failure early in the chain stalls everything after it, so the app that looks broken is often innocent.

Pushes land within ~10 minutes, or immediately with `flux reconcile`.

## Image automation

Three resources per app in `apps/base/<app>/image-automation.yaml`: an ImageRepository scanning the registry path, an ImagePolicy selecting a tag, and an ImageUpdateAutomation committing the result back to the deployment branch.

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

## Shared database

Postgres is shared. Each app gets its own database and user, bootstrapped by an init Job; superuser credentials are used only by that Job, never by the app. So a database-backed app carries two secrets: its own connection credentials, and a `db-init` secret holding the superuser password, the app password, and the host.

## Adding an app

Start with the base manifests, prod overlay, ExternalSecrets, and registry pull secret. Then handle the two misses that cost the most time:

1. Add it to `apps/prod/kustomization.yaml`. Forget this and nothing happens, silently.
2. If it uses the database, add an ingress allow for the new namespace to the **database's** NetworkPolicy. Forget this and you get a hang with no useful log line.
