## Host-specific: Isalas-MacBook-Pro (M3 Pro)

This machine hosts the infrastructure below. None of it is reachable from other machines.

- Main Kubernetes cluster: **polaris-v2**. Its GitOps manifests live in the `cumulus-gitops` repo, checked out next to this dotfiles repo. Resolve `~/.dotfiles` and look at its sibling directories to find it. Make changes via PRs to that repo, not by `kubectl apply` against the cluster.
