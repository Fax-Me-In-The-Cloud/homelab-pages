# Servarr

The `servarr` namespace hosts the media stack. Currently this consists of Jellyfin. The namespace is shared across all media services.

## Create the namespace

```bash
kubectl create namespace servarr
```

This must be done before deploying any service in this section.

## Services

| Service | Description |
|---|---|
| [Jellyfin](jellyfin/jellyfin.md) | Media server for streaming video and music |
