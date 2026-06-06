# Longhorn

[Longhorn](https://longhorn.io/) is a distributed block storage system for Kubernetes. It provides persistent volumes backed by replicated storage across nodes, with a web UI for managing volumes, snapshots, and backups.

Longhorn replaces the default local-path storage class that k3s ships with, giving persistent volumes that survive node failure.

## Check prerequisites

Longhorn has specific node requirements. The `longhornctl` tool checks them automatically.

First, make the k3s kubeconfig accessible:

```bash
mkdir -p ~/.kube
sudo install -o "$USER" -g "$USER" -m 600 /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

Using `install` copies the file with your user as the owner, so later
`kubectl` calls can read it. Avoid `sudo cp`, which leaves
`~/.kube/config` owned by root and unreadable to your normal user.

Download the `longhornctl` binary for ARM64 (Raspberry Pi):

```bash
curl -sSfL -o longhornctl https://github.com/longhorn/cli/releases/download/v1.9.0/longhornctl-linux-arm64
sudo chmod +x longhornctl
```

Run the preflight check:

```bash
sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml ./longhornctl check preflight
```

If the check reports missing packages (e.g. `open-iscsi`, `nfs-common`), the installer can handle them automatically across all nodes:

```bash
sudo ./longhornctl --kube-config ~/.kube/config --image longhornio/longhorn-cli:v1.9.0 install preflight
```

## Install with Helm

Install Helm if not already available:

```bash
brew install helm
```

Add the Longhorn Helm chart repository and install into a dedicated namespace:

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.9.0
```

Wait for all pods to come up — Longhorn deploys several components (manager, driver, UI):

```bash
kubectl -n longhorn-system get pod --watch
```

All pods should reach `Running` state. This can take a few minutes on the first install.

## Expose the UI

Longhorn's frontend service is initially behind a LoadBalancer. We delete that and replace it with a ClusterIP so Traefik can manage ingress:

```bash
kubectl delete service longhorn-frontend -n longhorn-system
kubectl apply -f longhorn-frontend.yaml
kubectl apply -f certificate.yaml
kubectl apply -f ingress.yaml
```

Wait for cert-manager to issue the certificate before testing the UI:

```bash
kubectl describe certificate longhorn-web-ui-tls -n longhorn-system
```

`Status: True` and `Reason: Ready` in the conditions means TLS is working. The UI will be available at `https://longhorn.local.spaelling.xyz`.

!!! note
    The ingress and certificate manifests (`longhorn-frontend.yaml`, `certificate.yaml`, `ingress.yaml`) live alongside this documentation. Traefik and cert-manager must be installed and working before applying them.
