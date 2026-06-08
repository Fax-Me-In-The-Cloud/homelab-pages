# Pi-hole

[Pi-hole](https://pi-hole.net/) provides DNS with network-wide ad blocking for the homelab. This page documents the **in-cluster** Pi-hole, which runs in k3s with a dedicated IP (`192.168.1.21`) assigned by kube-vip.

> **Role: secondary resolver (DNS2).** This `192.168.1.21` instance is the
> in-cluster secondary to the primary hardware Pi-hole at `192.168.1.60`. It is
> kept in sync (blocklists **and** local `*.local.spaelling.xyz` records) by a
> per-pod nebula-sync sidecar — see **[DNS redundancy](dns-redundancy.md)** for
> the architecture and full apply steps. Before adding it to DHCP, make sure the
> sync is working so it is a true equivalent of the primary.

The deployment uses the [pihole-kubernetes](https://github.com/MoJo2600/pihole-kubernetes) classic manifests.

## Install

Apply the kube-vip ConfigMap so Pi-hole gets its dedicated IP, then create the namespace and deploy:

```bash
kubectl apply -f kubevip-configmap.yaml
kubectl create namespace pihole
kubectl create secret -n pihole generic pihole-webpassword --from-literal="password=$(openssl rand -base64 64)"
# nebula-sync credentials (primary app password + localhost replica password):
kubectl create secret -n pihole generic nebula-sync-credentials --from-literal="primary=http://192.168.1.60|<PRIMARY_APP_PASSWORD>" --from-literal="replicas=http://localhost|<PIHOLE_WEBPASSWORD>"
kubectl apply -f pihole.yaml
```

`kubevip-configmap.yaml` is in the `k3s/kubevip` directory. The generated password is stored as a Kubernetes secret — retrieve it later with `kubectl get secret -n pihole pihole-webpassword -o jsonpath='{.data.password}' | base64 --decode`. The `nebula-sync-credentials` secret and the sync design are covered in **[DNS redundancy](dns-redundancy.md)**.

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
