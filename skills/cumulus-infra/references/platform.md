# Platform: networking, TLS, DNS

Cilium is CNI *and* ingress. It replaces flannel, kube-proxy, traefik, and servicelb. None of those exist here, so don't reach for an Ingress resource or a NodePort.

```yaml
kubeProxyReplacement: true
routingMode: native
autoDirectNodeRoutes: true
ipam: {mode: kubernetes}
gatewayAPI: {enabled: true, hostNetwork: {enabled: true}}
l2announcements: {enabled: false}
bpf: {masquerade: true, hostLegacyRouting: false, tproxy: true}
cni: {chainingMode: none, exclusive: true}
hubble: {enabled: false}
```

`devices` and `nodePort.directRoutingDevice` name the server's physical interface explicitly. It is **not** `eth0`; the installed name differs from what the rescue system used. Read it from `clusters/polaris-k3s/foundation/core/cilium-values.yaml` rather than assuming, and if the interface ever changes, that file changes with it.

Namespace convention: app name = namespace name, `-dev` suffix for the dev copy. Resource pressure is low by design, so don't set aggressive limits on new deployments.

## The single address

There is no LoadBalancer at all. The Gateway's Envoy runs on the host network and binds the node's port 443 directly, so the Gateway's address is just the node's own public IP. No LB-IPAM pool, no L2 announcements, no BGP, no MetalLB, no cloud load balancer. The Gateway's own Service is a NodePort nobody uses.

**Never create a LoadBalancer Service here.** It isn't merely useless — Cilium would claim the node IP as a service VIP, and its datapath then drops every non-service port on that address, taking SSH and DNS down with it. Everything ingresses through the one Gateway via HTTPRoute.

L2 announcements stay disabled on purpose. That beta feature answers ARP/NDP on a LAN for LoadBalancer or ExternalIP addresses; this node has a single routed public address and a host-network Gateway, so enabling it adds a failure surface without solving anything.

```bash
kubectl get gateway -n default -o wide   # ADDRESS should equal the node's IP
kubectl get node -o wide                 # INTERNAL-IP is the public IP
```

## Gateway listeners

One Gateway in `default`. **A wildcard and an apex hostname are always separate listeners**, and a domain carries only the listeners it actually needs — some have both, some only a wildcard, some only an apex plus one named subdomain. Each uses port 443, HTTPS, `Terminate`, and routes allowed from all namespaces.

Listeners and certificates are not one-to-one. A wildcard listener and its apex sibling share one Certificate whose `dnsNames` carry both patterns, so there are fewer certs than listeners. Do not conclude a listener is uncovered because no cert is named after it.

Routes attach by `sectionName`, so it must name the listener whose hostname pattern actually covers the route. An apex hostname pointed at a wildcard listener silently fails to attach. Read the live listeners rather than guessing:

```bash
kubectl get gateway <name> -n default \
  -o jsonpath='{range .spec.listeners[*]}{.name}{"\t"}{.hostname}{"\t"}{.tls.certificateRefs[0].name}{"\n"}{end}'
```

## TLS and DNS are automatic, with one exception

cert-manager provisions certs per listener via ACME DNS-01, and external-dns creates proxied records from HTTPRoutes. For a new hostname, creating the route is the entire DNS and certificate step.

DNS-01 needs no inbound traffic, which is why a cluster can hold valid certificates for its hostnames days before it serves any of them.

**The exception is a record external-dns does not own.** It runs `policy: sync` with a TXT registry: it only manages a record that has a matching `a-<name>` ownership TXT beside it. Records that predate it — typically apex A records created by hand — have no such TXT, so external-dns leaves them alone, and at info level it logs *nothing* about what it skipped. The symptom when moving clusters is that every subdomain flips and the bare domains keep answering from the old address. Move those by hand, or delete them once and let external-dns recreate and own them, accepting that `policy: sync` will then also delete them if their route disappears.

Two more things follow from the CDN:

- **`dig` never returns the node**, because records are proxied. Not a fault.
- The DNS provider API token is synced into both the cert-manager and external-dns namespaces, so when it expires **certificates and DNS break together.** Suspect it first when either misbehaves.

Never run two external-dns controllers against the same zones with the same `txtOwnerId`. They fight over every record forever. When handing records between clusters, stop the old one first, then start the new one.

Use the staging ClusterIssuer while iterating. Production rate limits cost a week.

## Default-deny everywhere

Every workload has a NetworkPolicy. Anything that can't reach anything is a missing egress rule until proven otherwise. DNS (53 UDP *and* TCP to kube-system) is required by everything, so omitting it makes unrelated things fail confusingly.

Never disable a policy to debug. Add the specific allow, test from inside the pod, keep it.

```bash
kubectl exec deploy/<app> -n <ns> -- nc -zv <svc>.<ns>.svc.cluster.local <port>
kubectl exec -n kube-system ds/cilium -- cilium policy get -n <ns>
```

## Adding a domain

Add the listeners it needs to `infrastructure/configs/gateway.yaml` and push. Certs and records follow on their own; you only point HTTPRoutes at the new `sectionName`.
