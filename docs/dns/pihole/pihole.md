# Pi-hole

[Pi-hole](https://pi-hole.net/) provides DNS with network-wide ad blocking for the homelab. This page documents the **in-cluster** Pi-hole, which runs in k3s with a dedicated IP (`192.168.1.21`) assigned by kube-vip.

> **Not currently in use.** This `192.168.1.21` instance is set up but is not active in the network today, and it does not hold records for local network servers (so it cannot resolve the `*.local.spaelling.xyz` internal domain). The sole DNS server in use is the primary resolver at `192.168.1.60`. The plan is to grow this into a redundant set of in-cluster Pi-hole resolvers — with local records — and eventually serve DNS from the cluster.

The deployment uses the [pihole-kubernetes](https://github.com/MoJo2600/pihole-kubernetes) classic manifests.

## Install

Apply the kube-vip ConfigMap so Pi-hole gets its dedicated IP, then create the namespace and deploy:

```bash
kubectl apply -f kubevip-configmap.yaml
kubectl create namespace pihole
kubectl create secret -n pihole generic pihole-webpassword --from-literal="password=$(openssl rand -base64 64)"
kubectl apply -f pihole.yaml
```

`kubevip-configmap.yaml` is in the `k3s/kubevip` directory. The generated password is stored as a Kubernetes secret — retrieve it later with `kubectl get secret -n pihole pihole-webpassword -o jsonpath='{.data.password}' | base64 --decode`.

## Verify DNS is working

Once pods are running, test that Pi-hole is answering DNS queries on its dedicated IP:

```bash
tcping -f 4 -t 5 192.168.1.21 53
nslookup google.com 192.168.1.21
```

Both should succeed. If `nslookup` returns an answer from `192.168.1.21`, Pi-hole is operational.

## Expose the admin UI

Apply the ingress for the primary Pi-hole instance:

```bash
kubectl apply -f pihole-0-ingress.yaml
```

This creates a Traefik `IngressRoute` for the Pi-hole web UI.

## Check logs

```bash
# Latest logs from the primary instance
kubectl logs pihole-0 -n pihole

# Stream logs in real time
kubectl logs -f pihole-0 -n pihole

# Logs from all replicas simultaneously
kubectl logs -l app=pihole -n pihole --all-containers

# DNS query log (inside the pod)
kubectl exec -it pihole-0 -n pihole -- tail -f /var/log/pihole/pihole.log
```

## Check rollout status

After making changes to the StatefulSet (e.g. updating the image or config), monitor the rollout:

```bash
kubectl rollout status statefulset pihole -n pihole
```
