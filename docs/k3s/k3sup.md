# k3sup

[k3sup](https://github.com/alexellis/k3sup) is a CLI tool that installs k3s on remote nodes over SSH and writes the kubeconfig to your local machine. It removes the need to SSH in manually and run the k3s install script by hand.

## Install k3sup

```bash
brew install k3sup
```

!!! note
    Most commands in the following sections run on the remote node with elevated privileges. k3sup handles this via `--sudo true`. If you need to run anything manually on the node, either use `sudo` or switch to root with `su`.

## Install the master node

If a kubeconfig from a previous cluster exists, remove it first to avoid conflicts:

```bash
rm -f ~/.kube/config
```

Install k3s on the first node. Key flags explained:

- `--cluster` — enables embedded etcd for HA (required even for a single server when you plan to add more)
- `--no-extras` — disables the bundled Traefik and ServiceLB (we install our own)
- `--tls-san` — adds extra SANs to the API server certificate so the VIP hostname and IP are both valid
- `--merge` — merges into an existing kubeconfig rather than overwriting

```bash
k3sup install --user pi --sudo true --ip 192.168.1.11 --cluster --k3s-channel stable --no-extras --local-path ~/.kube/config --merge --tls-san 192.168.1.10 --tls-san k3s.local.spaelling.xyz
```

### Validate the installation

Point kubectl at the new config and check the node is ready:

```bash
export KUBECONFIG=~/.kube/config
kubectl config use-context default
kubectl get node -o wide
```

Check the k3s systemd service on the node:

```bash
systemctl status k3s.service
cat /etc/systemd/system/k3s.service
```

Look for these flags in the `ExecStart` line:

```text
--tls-san k3s.local.spaelling.xyz --tls-san 192.168.1.10 --disable servicelb --disable traefik
```

If any of these are missing, the install did not apply all options correctly. Add the missing flags to the service file and restart:

```bash
systemctl daemon-reload
systemctl restart k3s.service
```

## Join additional nodes

To add a second server node (not an agent — this node also runs the control plane):

```bash
k3sup join --user pi --ip 192.168.1.12 --sudo true --server --server-ip 192.168.1.11 --server-user pi --k3s-channel stable --no-extras
```

`--server` makes this a server node rather than a worker-only agent. Omit it if you want a pure worker node.

After joining, verify the cluster sees all nodes:

```bash
kubectl get nodes -o wide
```

## Uninstall k3s

Run the uninstall script on each node individually. This removes k3s, its data, and the systemd service:

```bash
sudo /usr/local/bin/k3s-uninstall.sh
```

On agent-only nodes, the script is named `k3s-agent-uninstall.sh`:

```bash
sudo /usr/local/bin/k3s-agent-uninstall.sh
```
