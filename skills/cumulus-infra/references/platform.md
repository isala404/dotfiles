# Platform: networking, TLS, DNS

Cilium is CNI *and* ingress. It replaces flannel, kube-proxy, traefik, and servicelb. None of those exist here, so don't reach for an Ingress resource or a NodePort.

```yaml
gatewayAPI: {enabled: true}
l2announcements: {enabled: true}
kubeProxyReplacement: "true"
ipam: {mode: kubernetes}
routingMode: native
```

Namespace convention: app name = namespace name, `-dev` suffix for the dev copy. Resource pressure is low by design, so don't set aggressive limits on new deployments.

## The single address

The LoadBalancer pool holds exactly one address, announced by ARP on the node's primary interface, and the Gateway Service owns it. No BGP, no MetalLB.

Consequence: **a second LoadBalancer Service will sit Pending forever.** That's the design. Everything ingresses through the one Gateway via HTTPRoute.

```bash
kubectl get ciliumloadbalancerippool     # expect Available=0, Used=1
```

## Gateway listeners

One Gateway in `default`, with a **separate wildcard and apex listener per domain**. Each uses port 443, HTTPS, `Terminate`, routes allowed from all namespaces, and its own cert secret.

Routes attach by `sectionName`, so it must name the listener whose hostname pattern actually covers the route. An apex hostname pointed at a wildcard listener silently fails to attach. Read the live listeners rather than guessing:

```bash
kubectl get gateway <name> -n default \
  -o jsonpath='{range .spec.listeners[*]}{.name}{"\t"}{.hostname}{"\n"}{end}'
```

## TLS and DNS are automatic

cert-manager provisions a wildcard cert per listener via ACME DNS-01, and external-dns creates proxied records from HTTPRoutes. Creating a route with a hostname is the entire DNS and certificate step. There is no manual record to add.

Two things follow:

- **`dig` never returns the node**, because records are proxied by the CDN. Not a fault.
- The DNS provider API token is synced into both the cert-manager and external-dns namespaces, so when it expires **certificates and DNS break together.** Suspect it first when either misbehaves.

Use the staging ClusterIssuer while iterating. Production rate limits cost a week.

## Default-deny everywhere

Every workload has a NetworkPolicy. Anything that can't reach anything is a missing egress rule until proven otherwise. DNS (53 UDP *and* TCP to kube-system) is required by everything, so omitting it makes unrelated things fail confusingly.

Never disable a policy to debug. Add the specific allow, test from inside the pod, keep it.

```bash
kubectl exec deploy/<app> -n <ns> -- nc -zv <svc>.<ns>.svc.cluster.local <port>
kubectl exec -n kube-system ds/cilium -- cilium policy get -n <ns>
```

## Adding a domain

Add wildcard + apex listeners to the Gateway manifest in `infrastructure/configs/` and push. Certs and records follow on their own; you only point HTTPRoutes at the new `sectionName`.
