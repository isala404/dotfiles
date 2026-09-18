# The server itself

One Hetzner dedicated server running Debian 13, hostname `polaris`, one routed public IPv4 on a BIOS/GRUB install. Two NVMe drives in md RAID1: `/dev/md0` is `/boot`, `/dev/md1` is `/`, both ext4, no swap and no UEFI partition. RAID1 survives one drive dying and nothing else; it is not a backup.

The pieces that are easy to get wrong are all recorded in `infra/hetzner/` in the GitOps repo. Those scripts are the source of truth for how the host was built, and they are the thing to edit if the host needs to change, because nothing here is reconciled by Flux.

## The primary interface is not `eth0`

It is `enp0s31f6`, discovered at install time from whichever interface carried the public address and persisted to `/etc/cumulus/host.env` along with the hostname, address, gateway and boot mode. Read that file rather than guessing; Cilium's `devices` list names the same interface and will silently attach to nothing if it is wrong.

## Firewall

nftables, and the host owns exactly one table, `inet cumulus_host`, installed from `/etc/nftables.d/cumulus-host.nft`. Input policy is drop:

- 443 from the `cloudflare_v4` and `cloudflare_v6` sets only
- ICMP and ICMPv6 from anywhere
- 22, 6443, 10250 and 4240 from `10.0.0.0/8` and `100.64.0.0/10` only
- UDP 41641, which is Tailscale's direct-connection port
- whatever is in `failsafe_ports`, which is empty unless the tailnet watchdog has opened it

Port 80 is closed. The Gateway has no listener on it and both issuers solve dns01, so Cloudflare serves the redirect at the edge.

Forward and output stay accept, which native-routing Cilium needs.

**Never flush all tables.** Cilium owns tables of its own and clearing them breaks the datapath. Debian's packaged nftables unit flushes everything on stop, so a systemd drop-in replaces `ExecStart`/`ExecReload` with `/usr/local/sbin/cumulus-nftables-apply`, which deletes and reloads only the owned table. Apply firewall changes through that wrapper.

The table also carries a `gateway_mark_fix` chain, which is not firewalling. Cilium 1.20.2 ignores `enableXTSocketFallback: false` and installs an `xt_socket` rule that breaks every external connection to the host-network Gateway; the chain clears the mark that rule sets. `references/troubleshooting.md` has the full symptom. Delete the chain once the node runs Cilium 1.20.3 or newer.

**443 is Cloudflare-only, so you cannot test the origin directly.** `curl --resolve <host>:443:<public-ip>` times out by design; that is not a fault and not a reason to go looking at Envoy. Test through Cloudflare, or from the node itself. The two sets are refreshed daily by `cumulus-cloudflare-ips`, which validates a fetched list before installing it and keeps the previous one on rejection. If Cloudflare adds a range and every site fails at once, `systemctl start cumulus-cloudflare-ips.service` is the fix.

**SSH is tailnet-only, with a watchdog as the escape hatch.** `cumulus-tailscale-failsafe` runs every minute and adds 22 to `failsafe_ports` after ten consecutive failed tailnet checks, then removes it when the tailnet recovers, mailing on each transition. If you test it by hand, stop the timer first or the next tick undoes you. Deleting and recreating the table resets both the Cloudflare sets and the failsafe, which is why the apply wrapper re-runs both scripts.

The consequence for daily work: **the API server is unreachable from outside private ranges.** k3s itself binds `*:6443`, so this firewall is the only thing keeping the control plane off the internet. Never add a blanket accept for 6443 and never assume k3s is doing the restricting.

Tailscale bridges the gap. The host is joined as `polaris`, tagged `tag:infra`, so its tailnet address falls inside the permitted `100.64.0.0/10` and kubectl works with no tunnel. Tailscale SSH is on and hijacks port 22 on the tailnet address, so the node's own sshd is not what answers there. The ACL uses `action: check`, which means a browser confirmation: **scripted SSH over the tailnet hangs rather than failing.** For automation, open a multiplexed master and reuse it, since an established connection survives the firewall closing 22. It advertises no routes and accepts none: pulling tailnet subnet routes onto this node would risk colliding with the pod and service CIDRs.

## k3s configuration lives in a file, not in flags

`/etc/rancher/k3s/config.yaml`, whose source is `clusters/polaris-k3s/k3s-server-config.yaml`. Editing the systemd unit's flags instead will be reverted by the next installer run. What it sets that matters:

- SQLite datastore, single server. No `cluster-init`, no external endpoint.
- `secrets-encryption: true`. Secret values are encrypted inside `state.db` so a copy of the datastore is not a copy of every Secret. The decryption key at `/var/lib/rancher/k3s/server/cred/encryption-config.json` is deliberately *not* in the backup; losing the host means losing the Secrets, which is the accepted trade for the datastore backup being safe to store off-box.
- Cilium owns everything network: `flannel-backend: none`, kube-proxy, network policy and the packaged Helm controller disabled, traefik and servicelb disabled.

Enabling secrets encryption only affects subsequent writes. Existing Secrets stay in the clear until `k3s secrets-encrypt reencrypt --force --skip`, and superseded plaintext rows survive in kine until it compacts a few minutes later. Verify with a row count against `state.db`, not with the CLI's status output, and expect `runtime core not ready` for a few seconds after any k3s restart.

## Monitoring and mail

mdadm, smartd and unattended security updates are all enabled, and alerts reach mail@isala.me: `/usr/sbin/sendmail` is msmtp, relaying through Amazon SES as `polaris@tallisa.dev`. Automatic reboot is off, so a kernel update lands but does not apply itself — reboots are always a deliberate act, and on a single node they are downtime.

**SES rejects a message whose `To:` header is a bare local name**, with `554 Transaction failed: Missing final '@domain'`, even when the envelope is fully qualified. `/etc/aliases` rewrites the envelope and not the header, so mdadm's `MAILADDR`, smartd's `-m` and cron's `MAILTO` each need a full address written out. `root` silently produces nothing.

Journald is persistent, capped at 2G and 30 days. For anything the host itself reports — RAID resync, SMART, the firewall unit, k3s — the journal is the record, not the cluster's log pipeline, which only collects pod logs.
