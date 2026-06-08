# Nebula Sync

[Nebula Sync](https://github.com/lovelaze/nebula-sync) keeps multiple Pi-hole instances in sync. It replicates configuration (blocklists, whitelists, DNS records, settings) from a primary Pi-hole to one or more replicas, ensuring consistent behaviour across instances.

## Why

Running multiple Pi-hole replicas (as a StatefulSet) without synchronisation means each instance has an independent configuration. Any change made through the web UI of one instance is not reflected in the others. Nebula Sync solves this by treating one instance as the source of truth and pushing changes to the rest.

## Setup

Nebula Sync runs **per pod, as a sidecar** in the Pi-hole StatefulSet
(`pihole.yaml`) rather than as a central `CronJob`: each replica syncs *itself*
from the primary (`PRIMARY = 192.168.1.60`, `REPLICAS = http://localhost`). This
needs no per-pod addressing and scales automatically with the StatefulSet — see
[DNS redundancy](dns-redundancy.md) for the full rationale and apply steps.

Credentials come from the `nebula-sync-credentials` secret (the primary's
`http://host|app-password` and the localhost replica's `http://localhost|password`);
the replica password is the same `pihole-webpassword` used by Pi-hole itself.

Sync is **selective** (`FULL_SYNC=false`): DNS records, resolver and gravity
(blocklists/groups/clients) are replicated, but **DHCP and NTP are not** — the
primary owns DHCP and the cluster must never serve it.

## References

- [Nebula Sync GitHub](https://github.com/lovelaze/nebula-sync)
- [Pi-hole v6 API](https://pi-hole.net/)
