# Homelab

This is end-to-end documentation for building, rebuilding, and maintaining my homelab. It covers the full stack from bare hardware to running services.

Some values (IP addresses, domain names, credentials references) are specific to my setup, but the procedures are generic enough to follow on any similar cluster.

## Stack overview

| Layer | Technology |
|---|---|
| Hardware | 3× Raspberry Pi 5 (16 GB) nodes |
| Cluster | k3s (lightweight Kubernetes) |
| Virtual IP | kube-vip |
| Ingress | Traefik |
| TLS | cert-manager + Cloudflare DNS-01 |
| SSO | Authentik |
| Storage | Longhorn |
| Observability | Loki + Prometheus + Grafana (LGTM) |
| DNS | Pi-hole |
| Home Automation | Home Assistant + Matter Server + OTBR |
| Media | Jellyfin |

## Nodes

Three identical Raspberry Pi 5 boards form the cluster. All are control-plane
+ etcd members (k3s embedded HA), so any one can be lost without taking the
cluster down.

| Hostname | IP | Spec | Role |
|---|---|---|---|
| `rpi01` | `192.168.1.11` | Raspberry Pi 5 Model B (16 GB RAM, 4× Cortex-A76 @ arm64) | control-plane, etcd, master |
| `rpi02` | `192.168.1.12` | Raspberry Pi 5 Model B (16 GB RAM, 4× Cortex-A76 @ arm64) | control-plane, etcd, master |
| `rpi03` | `192.168.1.13` | Raspberry Pi 5 Model B (16 GB RAM, 4× Cortex-A76 @ arm64) | control-plane, etcd, master |

Common to all nodes: Debian 13 (Trixie), kernel `6.12.x-rpt-rpi-2712`, k3s
`v1.33.6+k3s1`. Each board also has the SoC's onboard Broadcom Bluetooth
(`hci0`, over the SoC UART) — used by the Matter Server on `rpi01` for BLE
commissioning (see Home Assistant → Matter Server).

## Network layout

| Address | Role |
|---|---|
| `192.168.1.1` | Gateway |
| `192.168.1.10` | k3s VIP (kube-vip) |
| `192.168.1.11` | `rpi01` — control-plane / master |
| `192.168.1.12` | `rpi02` — control-plane |
| `192.168.1.13` | `rpi03` — control-plane |
| `192.168.1.21` | In-cluster Pi-hole (kube-vip) — set up but not currently in use |
| `192.168.1.60` | DNS server — sole resolver in use, including local servers |
| `192.168.1.168` | smhub (Nano MG24) — Thread Border Router (OpenThread REST :8081) |

Internal services are exposed under `*.local.spaelling.xyz`, backed by Cloudflare-issued TLS certificates via DNS-01 challenge.

## Build order

Follow sections in this order for a clean build from scratch:

1. **Terminal** — set up local tooling (Warp, Starship, Homebrew)
2. **k3s** — prepare Raspberry Pi nodes, install k3s, kube-vip, Longhorn
3. **HTTPS** — install cert-manager, then Traefik
4. **Authentication** — install Authentik and configure SSO
5. **DNS** — deploy Pi-hole
6. **Observability** — deploy the LGTM stack
7. **Home Automation** — deploy Home Assistant and add-ons
8. **Media** — deploy Jellyfin
