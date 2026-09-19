---
name: cumulus-infra
description: Use when working on the cumulus k3s cluster, including kubectl, pods, deployments, GitOps and Flux changes, ingress, DNS, certs, storage and backups, the registry and CI, or debugging why something is down.
---

# Cumulus infrastructure

A single k3s node on one rented dedicated server. Cilium is CNI *and* ingress via Gateway API, with the Gateway's Envoy on the host network. FluxCD drives GitOps and image automation. State lives on local-path volumes on the node's RAID1 root and is protected by nightly logical dumps to S3-compatible object storage, not by replication. External Secrets Operator pulls from the configured secret provider. cert-manager and external-dns handle TLS and records automatically. Images come from a self-hosted registry that CI authenticates to by OIDC.

One box shapes most of the decisions below: no HA, one public address, and object storage as the only thing that survives losing it.

**This skill holds what's true because of how this cluster is built**, not general Kubernetes knowledge. Assume you already know the rest.

Domains, namespaces, and versions are deliberately absent. They're in the repo's `CLAUDE.md`, or discover them:

```bash
kubectl get gateway -A -o wide
kubectl get ns
```

## Rule zero: use the right secret skill

When a task involves BWS, Bitwarden, or provider-side credential retrieval, creation, or rotation, use the `bws-secrets` skill first. It owns credential access and handling; do not reproduce its commands or policies here.

For Kubernetes Secret objects, ExternalSecrets, or secret-sync behavior, read `references/secrets.md`. Never display a cluster-managed secret value.

## Rule one: the API is reachable over the tailnet only

The API server is not exposed to the internet. The host firewall allows 6443 from `10.0.0.0/8` and `100.64.0.0/10` only, so the node's tailnet address is the way in and no tunnel is needed.

```bash
kubectl config use-context polaris-k3s   # already the default
kubectl get nodes
```

The context points at the node's MagicDNS name on port 6443. **Check the context before anything that writes.** Other contexts on this machine are unrelated clusters and one of them is a retired host, so a bare `kubectl` after someone else switched contexts is a real hazard:

```bash
kubectl config current-context
```

SSH reaches the host over the same tailnet, as `ssh polaris`, so a tailnet outage takes out both paths at once. There is no public fallback to reach for: port 22 is closed on the public address, and 6443 never was open. What exists instead is a watchdog on the host that reopens 22 to the internet after the tailnet has been down for about ten minutes, at which point `ssh polaris-direct` works and can carry a forward:

```bash
ssh -M -S /private/tmp/polaris-tunnel.sock -f -N -L 16443:127.0.0.1:6443 polaris-direct
# point a copy of the kubeconfig at 127.0.0.1:16443
ssh -S /private/tmp/polaris-tunnel.sock -O exit polaris-direct
```

Keep the control socket path under 104 bytes, so not in a scratchpad directory, and close only your own socket. Never point a kubeconfig at the public address on 6443; the firewall drops it and the timeout looks like an outage.

`ssh polaris` is interactive by design. Tailscale SSH answers on the tailnet and the ACL uses `action: check`, so it prints a `login.tailscale.com` URL and waits for a browser confirmation. **Scripted SSH over the tailnet therefore hangs rather than failing**, which is easy to misread as the host being down. For automation, open one multiplexed master and reuse it; an established connection survives even the firewall closing 22 underneath it.

## References

| Task | Load |
|------|------|
| Kubernetes secrets and ExternalSecrets | `secrets.md` |
| Routing, DNS, TLS, network policy | `platform.md` |
| Manifests, the cluster overlay, image automation, adding an app | `gitops.md` |
| Build pipelines, dev vs prod images, registry auth | `ci-cd.md` |
| Storage, backups, restore, upgrades, hardening | `operations.md` |
| The server itself: disks, firewall, mail, k3s config | `host.md` |
| Logs, metrics, traces through the Cairn database | `observability.md` |
| Debugging | `troubleshooting.md` |

## Gotchas

- **Flux does not watch `main`.** It watches a separate deployment branch and commits image bumps back to it.
- **There is no `flux` CLI installed anywhere.** Drive reconciliation by annotating the resource; see `gitops.md` for the sequencing, which is not obvious.
- **Kustomize `commonLabels`** is deprecated but used everywhere. Keep it; migrate in one bulk change or not at all.
- **`EXPOSE` in a Dockerfile lies.** Check the runtime config for the real port.
- **Single node means no HA.** Any node-level operation is downtime; say so before starting one.
