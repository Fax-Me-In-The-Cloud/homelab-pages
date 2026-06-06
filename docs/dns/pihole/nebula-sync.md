# Nebula Sync

[Nebula Sync](https://github.com/lovelaze/nebula-sync) keeps multiple Pi-hole instances in sync. It replicates configuration (blocklists, whitelists, DNS records, settings) from a primary Pi-hole to one or more replicas, ensuring consistent behaviour across instances.

## Why

Running multiple Pi-hole replicas (as a StatefulSet) without synchronisation means each instance has an independent configuration. Any change made through the web UI of one instance is not reflected in the others. Nebula Sync solves this by treating one instance as the source of truth and pushing changes to the rest.

## Setup

!!! note
    Nebula Sync integration is not yet deployed. The following describes the intended configuration.

Deploy Nebula Sync as a Kubernetes `CronJob` in the `pihole` namespace. It should run frequently (e.g. every 5 minutes) to keep replicas in sync.

The CronJob needs:

- The Pi-hole API URL and password for the primary instance
- The Pi-hole API URL and password for each replica

Secrets for the Pi-hole admin password already exist as `pihole-webpassword` in the `pihole` namespace.

## References

- [Nebula Sync GitHub](https://github.com/lovelaze/nebula-sync)
- [Pi-hole v6 API](https://pi-hole.net/)
