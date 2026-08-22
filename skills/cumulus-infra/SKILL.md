---
name: cumulus-infra
description: Use when working on the cumulus k3s cluster, including kubectl, pods, deployments, GitOps and Flux changes, ingress, DNS, certs, Longhorn storage, the registry and CI, or debugging why something is down.
---

# Cumulus infrastructure

A single k3s node on one rented cloud VM. Cilium is CNI *and* ingress via Gateway API, with the Gateway's Envoy on the host network. FluxCD drives GitOps and image automation. Longhorn stores state at one replica, backed up off-box to S3-compatible object storage. External Secrets Operator pulls from the configured secret provider; Reloader restarts on change. cert-manager and external-dns handle TLS and records automatically. Images come from a self-hosted registry that CI authenticates to by OIDC.

Being one rented VM shapes most of the decisions below: no HA, one public address, and object storage as the only thing that survives losing the box.

**This skill holds what's true because of how this cluster is built**, not general Kubernetes knowledge. Assume you already know the rest.

Domains, namespaces, and versions are deliberately absent. They're in the repo's `CLAUDE.md`, or discover them:

```bash
kubectl get gateway -A -o wide
kubectl get ns
```

## Rule zero: use the right secret skill

When a task involves BWS, Bitwarden, or provider-side credential retrieval, creation, or rotation, use the `bws-secrets` skill first. It owns credential access and handling; do not reproduce its commands or policies here.

For Kubernetes Secret objects, ExternalSecrets, or secret-sync behavior, read `references/secrets.md`. Never display a cluster-managed secret value.

## Rule one: always pass `--context polaris-v2`

The kubeconfig has several contexts and a bare `kubectl` may hit the wrong cluster. Every command needs the flag; reference files omit it for brevity, you must not.

```bash
kubectl --context polaris-v2 get pods -A
```

Confirm it's the one you think with `kubectl config get-contexts`.

Auth is an exec credential plugin: kubectl shells out to `~/.kube/bws-credential-helper.sh`, which streams the kubeconfig out of the secret store and hands back client certs. It needs no prompt and no unlock, so kubectl works unattended. If it starts failing, the store is the thing to check, not the operator — see the `bws-secrets` skill.

## References

| Task | Load |
|------|------|
| Kubernetes secrets and ExternalSecrets | `secrets.md` |
| Routing, DNS, TLS, network policy | `platform.md` |
| Manifests, image automation, adding an app | `gitops.md` |
| Build pipelines, dev vs prod images, registry auth | `ci-cd.md` |
| Upgrades, storage, backups, hardening | `operations.md` |
| Debugging | `troubleshooting.md` |

## Gotchas

- **Flux does not watch `main`.** It watches a separate deployment branch and commits image bumps back to it.
- **Kustomize `commonLabels`** is deprecated but used everywhere. Keep it; migrate in one bulk change or not at all.
- **`EXPOSE` in a Dockerfile lies.** Check the runtime config for the real port.
- **Single node means no HA.** Any node-level operation is downtime; say so before starting one.
- Prefer the `flux` CLI over raw kubectl for kustomizations, HelmReleases, and image automation.
