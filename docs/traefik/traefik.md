# Traefik

[Traefik](https://traefik.io/) is the ingress controller for the cluster. It handles all inbound HTTP/HTTPS traffic, terminates TLS, and routes requests to services based on `IngressRoute` rules.

k3s is installed with `--no-extras` which disables the bundled Traefik. We install it separately via Helm to have full control over the configuration.

## Install

Add the Traefik Helm chart repository:

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

Create the namespace and install with custom values:

```bash
kubectl create ns traefik
helm install --namespace=traefik --values=./traefik-values.yml traefik traefik/traefik
```

All available Helm values are documented in the [Traefik Helm chart](https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml).

Verify the pod is running and has an external IP assigned by kube-vip:

```bash
kubectl get pods --namespace traefik
kubectl get svc --namespace traefik
```

The `traefik` service should have an `EXTERNAL-IP` of `192.168.1.10`.

## Configure the kube-vip cloud provider

Create the ConfigMap that tells the kube-vip cloud provider which IP to assign to Traefik's LoadBalancer service. The manifest is in the `k3s/kubevip` directory:

```bash
kubectl apply -f kubevip-configmap.yaml
```

This maps the `traefik` namespace service to the VIP `192.168.1.10`.

## Create the Traefik dashboard certificate

Issue a TLS certificate for the Traefik dashboard:

```bash
kubectl apply -f dashboard-certificate.yaml
```

## Upgrade

When changing values in `traefik-values.yml`, upgrade the release rather than reinstalling:

```bash
helm upgrade --namespace=traefik --values=./traefik-values.yml traefik traefik/traefik
```

## Authentik middleware

Once Authentik is running, apply the forward-auth middleware to protect the Traefik dashboard and other services:

```bash
kubectl apply -f authentik-middleware.yaml
```

This creates a Traefik `Middleware` resource that forwards authentication decisions to Authentik's outpost.

## Troubleshooting

Check pod status and describe them if not ready:

```bash
kubectl get pods -n traefik
kubectl get pods -n traefik --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe pod {} -n traefik
```

Check the IngressRoute and TLS secret for the dashboard:

```bash
kubectl describe ingressroute traefik-dashboard -n traefik
kubectl describe secrets traefik-dashboard-tls -n traefik
```

Dump Traefik logs to a file for detailed inspection:

```bash
kubectl logs -n traefik -l app.kubernetes.io/name=traefik > traefik.log
```

If a service shows the default Traefik certificate instead of a Let's Encrypt certificate, check that the `IngressRoute` references the correct TLS secret name and that the cert-manager certificate is in `Ready` state.
