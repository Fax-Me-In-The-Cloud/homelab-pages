# Authentik

[Authentik](https://goauthentik.io/) is the identity provider for the homelab. It provides SSO via OAuth2/OIDC and forward-auth, protecting internal services behind a login screen without each service needing its own authentication.

Services integrated with Authentik: Grafana, Traefik dashboard, and any other internal web UI.

> **Status: not currently deployed.** Authentik is documented here but is not running in the cluster at the moment.

## Prerequisites

Traefik and cert-manager must be running before installing Authentik, as the Helm values reference an `IngressRoute` and a cert-manager `Certificate`.

The `authentik-credentials.yaml` file contains the secret key and PostgreSQL password. This file is stored in the password vault and is not committed to the repository.

## Install

```bash
kubectl create namespace authentik
kubectl apply -f authentik-certificate.yaml
helm repo add authentik https://charts.goauthentik.io
helm repo update
helm upgrade --install authentik authentik/authentik --namespace=authentik -f authentik-values.yaml,authentik-credentials.yaml
```

`authentik-values.yaml` is in this directory. `authentik-credentials.yaml` comes from the password vault.

## Verify pods are healthy

Check the PostgreSQL database first — Authentik will not start if the database is unavailable:

```bash
kubectl describe pods -n authentik -l app.kubernetes.io/name=postgresql
```

Then check the Authentik server and worker:

```bash
kubectl describe pods -n authentik -l app.kubernetes.io/name=authentik,app.kubernetes.io/component=server
kubectl describe pods -n authentik -l app.kubernetes.io/name=authentik,app.kubernetes.io/component=worker
```

And Redis (used for session caching):

```bash
kubectl describe pods -n authentik -l app.kubernetes.io/name=redis
```

Check the TLS certificate, secret, and ingress:

```bash
kubectl describe certificates authentik-tls -n authentik
kubectl get secret authentik-tls -n authentik -o yaml
kubectl get ingress -n authentik -o yaml
```

Test the endpoint:

```bash
curl -kv https://authentik.local.spaelling.xyz/
```

If the response shows `subject: CN=TRAEFIK DEFAULT CERT`, the Authentik TLS secret is not being picked up by Traefik. Check the `IngressRoute` to confirm it references the correct secret name, and verify the certificate is in `Ready` state.

## First login

Navigate to the initial setup flow:

```
https://authentik.local.spaelling.xyz/if/flow/initial-setup/
```

1. Create the first admin user
2. Add the user to the `authentik Admins` group
3. Go to **Settings → MFA Devices** and register a passkey
4. Deactivate the default `akadmin` user

## Certificates

Two certificates are needed:

1. **Service certificate** — for the Authentik web UI itself (`authentik-certificate.yaml`)
2. **Outpost certificate** — for the embedded outpost that handles forward-auth for other services

The outpost certificate is referenced in `authentik-values.yaml` and is created by the same cert-manager `ClusterIssuer`.

## Logs

```bash
kubectl logs -n authentik -l app.kubernetes.io/name=authentik,app.kubernetes.io/component=server --tail=-1 > authentik-server.log

kubectl logs -n authentik -l app.kubernetes.io/name=postgresql --tail=-1 > authentik-postgresql.log
```

## Restart

If the server is in a bad state, a rollout restart is usually sufficient:

```bash
kubectl rollout restart deployment authentik-server -n authentik
```

## Uninstall

Helm uninstall does not remove Persistent Volume Claims. Delete them manually to fully clean up:

```bash
helm uninstall authentik --namespace=authentik

kubectl get pvc -n authentik -o jsonpath="{.items[*].metadata.name}" | tr ' ' '\n' | xargs -I {} kubectl delete pvc {} -n authentik

kubectl delete secret authentik-secret-key --namespace authentik
kubectl delete secret authentik-postgresql-password --namespace authentik
```
