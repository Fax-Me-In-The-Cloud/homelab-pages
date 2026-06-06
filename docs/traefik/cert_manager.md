# cert-manager

[cert-manager](https://cert-manager.io/) automates the provisioning and renewal of TLS certificates. It integrates with Let's Encrypt using the DNS-01 challenge via Cloudflare, which means certificates can be issued for internal services without exposing them to the public internet.

## Install

Install Helm if not already available:

```bash
brew install helm
```

Add the Jetstack chart repository and install cert-manager with CRD support:

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.18.0 --set crds.enabled=true
```

Verify all pods are running:

```bash
kubectl -n cert-manager get pod
```

## Cloudflare issuer configuration

cert-manager uses a Cloudflare API token to prove domain ownership via DNS-01. The token is stored as a Kubernetes secret.

### Create the Cloudflare API token

1. Go to the [Cloudflare API Tokens page](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token** and select the **Edit zone DNS** template
3. Under **Zone Resources**, select the specific zone (`spaelling.xyz`)
4. Optionally restrict the token to your cluster's egress IP under **Client IP Address Filtering**
5. Create the token and save it — it is only shown once

### Apply the secret and issuer

The manifests are in `docs/traefik/`:

```bash
cd ~/git/Privat/homelab-pages/docs/traefik
kubectl apply -n cert-manager -f cloudflare_api_token.yaml
kubectl apply -f acme_clusterissuer.yaml
```

`cloudflare_api_token.yaml` creates a secret containing the API token. `acme_clusterissuer.yaml` defines a `ClusterIssuer` that references that secret and configures the Let's Encrypt ACME server.

For reference, see:

- [cert-manager Cloudflare DNS-01 docs](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
- [Creating a ClusterIssuer](https://cert-manager.io/docs/configuration/acme/#creating-a-basic-acme-issuer)

## Force recursive DNS for ACME challenges

By default, cert-manager uses the cluster's internal DNS to verify challenges. This can cause failures when the cluster's DNS points to Pi-hole or another local resolver that does not resolve `*.acme.invalid`. Force cert-manager to use public DNS resolvers instead:

```bash
kubectl edit deployment cert-manager -n cert-manager
```

Find the `args:` list under `containers` and add the two `--dns01` flags:

```yaml
containers:
  - args:
    - --v=2
    - --cluster-resource-namespace=$(POD_NAMESPACE)
    - --leader-election-namespace=kube-system
    - --dns01-recursive-nameservers-only
    - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
```

Restart cert-manager to apply the change:

```bash
kubectl rollout restart deployment cert-manager -n cert-manager
```

## Troubleshooting

Certificate issuance goes through several stages: `Certificate` → `CertificateRequest` → `Order` → `Challenge`. Inspect each in turn to find where a failure occurs:

```bash
kubectl get certificates -n traefik --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe certificates {} -n traefik

kubectl get certificaterequests -n traefik --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe certificaterequests {} -n traefik

kubectl get order -n traefik --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe order {} -n traefik

kubectl get challenges -n traefik --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe challenges {} -n traefik
```

Common causes of failure:

- API token lacks DNS edit permissions for the zone
- Challenge still pending because Cloudflare DNS propagation is slow (wait a minute and retry)
- cert-manager using local DNS — apply the recursive DNS fix above
