# DNS redundancy

Goal: stop the hardware Raspberry Pi from being a single point of failure for
DNS, by running **secondary Pi-hole resolvers in the k3s cluster** that stay in
sync with it.

## Architecture

Two **independent failure domains**, both handed out to clients by DHCP:

| Role | Address | Hosting | Notes |
|---|---|---|---|
| **DNS1** (primary) | `192.168.1.60` | Dedicated hardware Raspberry Pi | Source of truth; owns DHCP. |
| **DNS2** (secondary) | `192.168.1.21` | k3s (StatefulSet, 3 pods) | HA via kube-vip VIP + Service across in-sync pods. |

If the hardware Pi dies, the cluster keeps resolving; if the whole cluster dies,
the hardware Pi keeps resolving. Point DHCP's DNS options at **both** addresses.

!!! warning "It's failover, not load-balancing"
    Clients favour DNS1 and only fall back to DNS2 on timeout, and the fallback
    is client-dependent. So DNS2 must be a *full equivalent* of DNS1 — same
    blocklists **and** the same local `*.local.spaelling.xyz` records — or you
    get inconsistent blocking and broken internal names after a failover.

## Keeping the secondary in sync

[nebula-sync](https://github.com/lovelaze/nebula-sync) replicates Pi-hole **v6**
configuration (local DNS records, blocklists, groups, settings) from a primary
to replicas over the v6 API.

It runs **per pod, as a sidecar** in the Pi-hole StatefulSet, with
`PRIMARY = 192.168.1.60` and `REPLICAS = http://localhost`. Each replica
therefore syncs *itself* from the hardware Pi. Compared with one central
`CronJob`:

- **No per-pod addressing.** A central job would have to reach each pod
  individually (the `192.168.1.21` Service load-balances, so it can't), needing
  a headless service and a hand-maintained replica list. The sidecar syncs to
  `localhost`, so none of that applies.
- **Auto-scales.** Change `replicas` and new pods sync themselves — nothing else
  to edit.
- **Self-healing.** A restarted pod re-syncs on its schedule; its PVC also keeps
  the last-synced config across restarts.

Sync is **selective** so the cluster never inherits the primary's DHCP role:

- **On:** DNS config (local records/CNAMEs), resolver, and gravity
  (groups, adlists, domain lists, clients).
- **Off:** `SYNC_CONFIG_DHCP`, `SYNC_CONFIG_NTP`, DHCP leases.

The local `*.local.spaelling.xyz` records are *also* shipped as a dnsmasq
`ConfigMap` (`pihole-local-records`) so internal names resolve from the moment a
pod starts, before the first sync.

### Why not the alternatives

| Option | Verdict |
|---|---|
| **orbital-sync** | Works on v6 (teleporter, like nebula-sync). Fine alternative; no strong reason to switch. |
| **gravity-sync** | Archived/EOL — it was v5-only (rsync of the SQLite gravity DB). Don't use on v6. |
| **Shared RWX volume** (one DB for all pods) | Don't — FTL's SQLite isn't multi-writer safe; corruption risk. |
| **Pure declarative config** | Used here only for the static parts (local records, upstreams); the dynamic config (blocklists, allow/deny edited on the primary) still needs sync. |

## Apply

These manifests are config-as-code — apply them yourself; nothing here changes
the running cluster on its own.

Create the two secrets, then apply:

```bash
kubectl create namespace pihole

# Pi-hole web/API password (also the localhost replica password for nebula-sync)
kubectl create secret -n pihole generic pihole-webpassword --from-literal="password=$(openssl rand -base64 24)"

# nebula-sync credentials. Each value is one "http://host|password" string.
# - primary:  the hardware Pi-hole + an APP PASSWORD created in its UI
#             (Settings -> Web interface / API -> App passwords).
# - replicas: localhost + the pihole-webpassword value used above.
kubectl create secret -n pihole generic nebula-sync-credentials --from-literal="primary=http://192.168.1.60|<PRIMARY_APP_PASSWORD>" --from-literal="replicas=http://localhost|<PIHOLE_WEBPASSWORD>"

kubectl apply -f pihole.yaml
```

Then fill in `pihole-local-records` (the `address=` lines) with your real
internal records, or leave it for nebula-sync to populate from the primary.

## Verify

```bash
kubectl -n pihole rollout status statefulset/pihole
kubectl -n pihole logs <pod> -c nebula-sync         # sync results
nslookup <a-host>.local.spaelling.xyz 192.168.1.21  # internal record resolves
nslookup doubleclick.net 192.168.1.21               # blocked by gravity
```

Finally, add `192.168.1.21` as the **secondary DNS** in your DHCP scope and
confirm clients receive both resolvers.

## References

- [nebula-sync](https://github.com/lovelaze/nebula-sync)
- [High Availability DNS/DHCP with Pi-hole 6](https://homelab.casaursus.net/high-availability-pi-hole-6/)
