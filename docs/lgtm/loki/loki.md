# Loki

[Loki](https://grafana.com/oss/loki/) is the log aggregation component of the LGTM stack. It stores and indexes logs from all pods in the cluster, queryable via Grafana.

## Prerequisites

Create the `lgtm` namespace before installing any component in this stack — Loki, Prometheus, and Grafana all share it:

```bash
kubectl create namespace lgtm
```

## Install

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki -f loki-values.yaml -n lgtm
```

Verify the pods are running:

```bash
kubectl get pods -n lgtm -l app.kubernetes.io/name=loki
```

## Upgrade

```bash
helm upgrade loki grafana/loki --values loki-values.yaml -n lgtm
```

## Internal cluster endpoints

Other services in the cluster send logs and query Loki using its cluster-internal DNS name:

| Use | URL |
|---|---|
| Push logs to Loki | `http://loki-gateway.lgtm.svc.cluster.local/loki/api/v1/push` |
| Grafana datasource | `http://loki-gateway.lgtm.svc.cluster.local/` |

## Kubernetes log monitoring

The `k8s-monitoring` Helm chart deploys Grafana Alloy as a DaemonSet to collect logs and metrics from every node and forward them to Loki and Prometheus:

```bash
helm install k3smon grafana/k8s-monitoring --values k3s-monitoring-values.yml -n lgtm
```

To upgrade:

```bash
helm upgrade k3smon grafana/k8s-monitoring --values k3s-monitoring-values.yml -n lgtm
```

Validate that Alloy is collecting and forwarding logs:

```bash
kubectl logs -n lgtm -l app.kubernetes.io/name=alloy --tail=50
```

Look for lines confirming successful connections to the Loki push endpoint.

All Alloy Helm values are documented in the [Alloy chart repository](https://github.com/grafana/alloy/blob/main/operations/helm/charts/alloy/values.yaml).
