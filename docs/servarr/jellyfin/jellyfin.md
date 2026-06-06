# Jellyfin

[Jellyfin](https://jellyfin.org/) is an open-source media server. It streams video, music, and photos to browsers and clients on the local network, protected by Traefik and Authentik.

## Prerequisites

The `servarr` namespace must exist — create it first if not already done (see [Servarr](../servarr.md)).

The deployment uses Kustomize overlays to manage environment-specific configuration.

## Deploy

```bash
kubectl apply -k overlay
```

Run this from the `docs/servarr/jellyfin/` directory where the `overlay/` folder lives.

Verify the pod comes up:

```bash
kubectl get pods -n servarr -l app=jellyfin
```

## First run

On first start, Jellyfin runs a setup wizard. Navigate to `https://jellyfin.local.spaelling.xyz` and follow the prompts to:

1. Create the initial admin user
2. Add media libraries (point to the Longhorn PVC mount paths)
3. Configure transcoding if hardware acceleration is available

## Upgrade

To update Jellyfin, change the image tag in the Kustomize overlay and re-apply:

```bash
kubectl apply -k overlay
```

Jellyfin does not perform zero-downtime restarts — expect a brief interruption during the pod restart.
