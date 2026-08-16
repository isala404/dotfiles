---
name: cumulus-infra
description: Use when working on the cumulus k3s cluster, including kubectl, pods, deployments, GitOps and Flux changes, ingress, DNS, certs, Longhorn storage, the registry and CI, or debugging why something is down.
---

# Cumulus Infrastructure

A single k3s node on a Hetzner cloud server. Cilium is CNI *and* ingress via Gateway API. FluxCD drives GitOps and image automation. Longhorn stores state at one replica, backed up off-box to S3-compatible object storage. External Secrets Operator pulls from Bitwarden; Reloader restarts on change. cert-manager and external-dns handle TLS and records automatically. Images come from a self-hosted registry that CI authenticates to by OIDC.

Being one rented VM shapes most of the decisions below: no HA, one public address, and object storage as the only thing that survives losing the box.

**This skill holds what's true because of how this cluster is built**, not general Kubernetes knowledge. Assume you already know the rest.

Domains, namespaces, versions, and secret IDs are deliberately absent. They're in the repo's `CLAUDE.md`, or discover them:

```bash
kubectl get gateway -A -o wide
kubectl get ns
```

## Rule zero: don't spill secrets

Read `references/secrets.md` before anything involving secrets, `.env` files, credentials, or ExternalSecrets. Short version: you may pipe a value into a command, you may not print one. This cluster's secrets are never displayed; dev and throwaway credentials the operator hands you are workable material.

## Rule one: always pass `--context polaris-v2`

The kubeconfig has several contexts and a bare `kubectl` may hit the wrong cluster. Every command needs the flag; reference files omit it for brevity, you must not.

```bash
kubectl --context polaris-v2 get pods -A
```

Confirm it's the one you think with `kubectl config get-contexts`.

Auth is an exec credential plugin behind a biometric-unlocked keychain, cached about an hour. You cannot re-auth non-interactively; when it expires, ask the operator to unlock.

## References

| Task | Load |
|------|------|
| Anything secret-shaped | `secrets.md` |
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
