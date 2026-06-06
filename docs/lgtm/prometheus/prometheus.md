# Prometheus

[Prometheus](https://prometheus.io/) is the metrics backend of the LGTM stack. The `kube-prometheus-stack` Helm chart bundles Prometheus, Alertmanager, and a set of pre-built Kubernetes dashboards and alerting rules.

## Prerequisites

The `lgtm` namespace must exist — create it if not already done (see [Loki](../loki/loki.md)).

## Install

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack --values prometheus-values.yaml -n lgtm
```

Verify the stack is running:

```bash
kubectl --namespace lgtm get pods -l "release=prometheus"
```

The chart deploys several components: `prometheus-server`, `alertmanager`, `kube-state-metrics`, and `node-exporter` pods on each node.

## Upgrade

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack --values prometheus-values.yaml -n lgtm
```

## Grafana datasource URL

When configuring Prometheus as a datasource in Grafana, use the cluster-internal service URL:

```
http://prometheus-kube-prometheus-prometheus.lgtm.svc.cluster.local:9090
```

This is already set in `grafana-values.yaml` — no manual configuration is needed unless you are setting up Grafana fresh.

## Reference

- [kube-prometheus-stack chart](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md)
