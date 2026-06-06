# kube-vip

[kube-vip](https://kube-vip.io/) provides a virtual IP (VIP) for the k3s API server and a load balancer for Kubernetes services. It uses ARP-based leader election to move the VIP between nodes if the current leader goes down.

In this setup:

- VIP: `192.168.1.10` — DNS name `k3s.local.spaelling.xyz`
- Interface: `eth0`

kube-vip is deployed as a DaemonSet on control-plane nodes, managed by k3s's auto-deploy manifests directory (`/var/lib/rancher/k3s/server/manifests/`).

## Install kube-vip

All commands run on the master node as root.

### Create the manifests directory

k3s watches this directory and automatically deploys any YAML files placed in it:

```bash
mkdir -p /var/lib/rancher/k3s/server/manifests/
```

### Upload the RBAC manifest

kube-vip needs cluster-level RBAC permissions to watch nodes and services:

```bash
curl https://kube-vip.io/manifests/rbac.yaml > /var/lib/rancher/k3s/server/manifests/kube-vip-rbac.yaml
```

### Generate the DaemonSet manifest

Fetch the latest kube-vip release version and generate the manifest. The `alias` wraps `ctr` (containerd) to run kube-vip as a one-shot container to produce the YAML:

```bash
export VIP=192.168.1.10
export INTERFACE=eth0
apt install -y jq curl
KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")
alias kube-vip="ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION; ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip"

kube-vip manifest daemonset --interface $INTERFACE --address $VIP --inCluster --taint --controlplane --services --arp --leaderElection | tee /var/lib/rancher/k3s/server/manifests/kube-vip.yaml
```

Key flags:

- `--taint` — only runs on control-plane nodes
- `--controlplane` — manages the API server VIP
- `--services` — also manages LoadBalancer service IPs
- `--arp` — uses ARP for IP advertisement (no BGP required)
- `--leaderElection` — enables leader election between control-plane nodes

k3s picks up the new manifest automatically. Verify the pods are running:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip
```

## Configure DNS

Add an A record pointing `k3s.local.spaelling.xyz` to `192.168.1.10` in your DNS server (Pi-hole or your router).

Update the kubeconfig to use the DNS name instead of the node IP, so the config remains valid even if nodes change:

```bash
sudo nano ~/.kube/config
```

Change the `server:` line to:

```yaml
server: https://k3s.local.spaelling.xyz:6443
```

## Install the kube-vip Cloud Provider

The cloud provider controller handles `LoadBalancer` service IP assignment. It reads from a ConfigMap to determine which IP pool to use:

```bash
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
```

!!! note
    The ConfigMap that tells the cloud provider which IP range to assign is created later, during Traefik setup. Traefik is the only service that needs a LoadBalancer IP, and it gets `192.168.1.10`.
