# Metrics Drop Process

This document classifies the monitor cluster metric drop strategy by functional component, and records the extracted rule snippets under `configs/pipelines/metric-drop/`.

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

The goal of metric dropping is to reduce TSDB pressure, lower remote write bandwidth, and keep dashboards and alerts focused on high-value signals.

This classification is based on the actual scrape components, such as `node-exporter`, `kubelet`, and `kube-apiserver`, not on generic rule types.

For the retained raw metrics:

> [retained-metrics-overview.md](../../templates/markdown/retained-metrics-overview.md)

## Classification of Configuration Files

The actual source of truth is:

> [monitor-kube-prometheus-stack-values.yaml](../../configs/pipelines/prometheus_stack-install/monitor-kube-prometheus-stack-values.yaml)

For easier review and reuse, the component rule blocks have been split into:

- [metric-drop/alertmanager.yaml](../../configs/pipelines/metric-drop/alertmanager.yaml)
- [metric-drop/coredns.yaml](../../configs/pipelines/metric-drop/coredns.yaml)
- [metric-drop/kube-state-metrics.yaml](../../configs/pipelines/metric-drop/kube-state-metrics.yaml)
- [metric-drop/kube-apiserver.yaml](../../configs/pipelines/metric-drop/kube-apiserver.yaml)
- [metric-drop/kube-controller-manager.yaml](../../configs/pipelines/metric-drop/kube-controller-manager.yaml)
- [metric-drop/kube-scheduler.yaml](../../configs/pipelines/metric-drop/kube-scheduler.yaml)
- [metric-drop/kubelet.yaml](../../configs/pipelines/metric-drop/kubelet.yaml)
- [metric-drop/prometheus.yaml](../../configs/pipelines/metric-drop/prometheus.yaml)
- [metric-drop/node-exporter.yaml](../../configs/pipelines/metric-drop/node-exporter.yaml)
- [metric-drop/prometheus-operator.yaml](../../configs/pipelines/metric-drop/prometheus-operator.yaml)

These files are extracted rule references. If the strategy changes, the matching section in `monitor-kube-prometheus-stack-values.yaml` must still be updated.

## Component Classification

### Alertmanager

Config:

> [alertmanager.yaml](../../configs/pipelines/metric-drop/alertmanager.yaml)

Dropped metric types:

- alert lifecycle counters such as received, invalid, and marked alerts
- dispatcher, notification, HTTP request, nflog, silence, inhibition, receiver, and integration internals
- build and cluster metadata
- generic `go_*`, `process_*`, `promhttp_*`, and `reloader_*`
- selected notification counters by `integration` label

### CoreDNS

Config:

> [coredns.yaml](../../configs/pipelines/metric-drop/coredns.yaml)

Dropped metric types:

- all histogram bucket series
- build metadata
- request and response size histograms
- proxy cache, health, hosts reload, and kubernetes plugin programming internals
- generic `go_*` and `process_*`

### kube-state-metrics

Config:

> [kube-state-metrics.yaml](../../configs/pipelines/metric-drop/kube-state-metrics.yaml)

Dropped metric types:

- all histogram bucket series
- node, namespace, pod, deployment, daemonset, replicaset, statefulset, job, and cronjob metadata-heavy series
- service, endpoint, ingress, networkpolicy, secret, configmap, storageclass, lease, and webhook configuration metrics
- persistent volume metadata such as claim reference and creation info

### kube-apiserver

Config:

> [kube-apiserver.yaml](../../configs/pipelines/metric-drop/kube-apiserver.yaml)

Dropped metric types:

- selected request and etcd latency buckets, plus all remaining bucket series
- `grpc_client_*`, `rest_client_*`, `workqueue_*`
- registered, hidden, and disabled metric bookkeeping
- build, feature, `go_*`, `process_*`, `k3s_*`, and `lasso_*`
- deep control-plane internals such as flow-control, authn or authz internals, watch cache, storage, endpoint slice, kubelet, kube-proxy, scheduler, and etcd detail

### kube-controller-manager

Config:

> [kube-controller-manager.yaml](../../configs/pipelines/metric-drop/kube-controller-manager.yaml)

Dropped metric types:

- all histogram bucket series
- `grpc_client_*`, `rest_client_*`, `workqueue_*`
- registered, hidden, and disabled metric bookkeeping
- build, feature, `go_*`, `process_*`, `k3s_*`, and `lasso_*`
- apiserver interaction, endpoint slice, service controller, node controller, storage, kubelet, kube-proxy, and scheduler internal metrics

### kube-scheduler

Config:

> [kube-scheduler.yaml](../../configs/pipelines/metric-drop/kube-scheduler.yaml)

Dropped metric types:

- all histogram bucket series
- `grpc_client_*`, `rest_client_*`, `workqueue_*`
- registered, hidden, and disabled metric bookkeeping
- build, feature, `go_*`, `process_*`, `k3s_*`, and `lasso_*`
- scheduler framework timing detail plus broad control-plane internals

### kubelet

Config:

> [kubelet.yaml](../../configs/pipelines/metric-drop/kubelet.yaml)

Applies to:

- `cAdvisorMetricRelabelings`
- `metricRelabelings`
- `probesMetricRelabelings`

Dropped metric types:

- cAdvisor container CPU, filesystem, memory, socket, spec, machine metadata, and last-seen style metrics
- noisy network interface metrics for `cali`, `cilium`, `cni`, `lxc`, `nodelocaldns`, and `tunl`
- orphan container samples identified by `id` and `pod`
- generic bucket, gRPC, REST, workqueue, build, feature, `go_*`, `process_*`, `k3s_*`, and `lasso_*`
- kubelet runtime, pod start or sync, PLEG, topology, CPU or memory manager, volume operation, kube-proxy, kube-router, and cross-control-plane internal metrics
- selected `csi_operations` and `storage_operation_duration` buckets
- `prober_*` metrics

### Prometheus

Config:

> [prometheus.yaml](../../configs/pipelines/metric-drop/prometheus.yaml)

Dropped metric types:

- all histogram bucket series
- generic runtime and process metrics such as `go_*`, `process_*`, `net_conntrack_*`, and `promhttp_*`
- API notification, notification delivery, HTTP server, template, treecache, engine, service discovery, and reloader internals
- most remote storage internals
- most TSDB internal metrics and target scrape volume metrics
- federation warning and error counters

Special handling:

- `prometheus_tsdb_storage_blocks_bytes` is preserved by temporarily marking it with `__keep_tsdb` before dropping the remaining `prometheus_tsdb_*` metrics

### node-exporter

Config:

> [node-exporter.yaml](../../configs/pipelines/metric-drop/node-exporter.yaml)

Dropped metric types:

- most `go_*`, `process_*`, `promhttp_*`, and `node_scrape_collector_*`
- most time, timex, vmstat, softnet, schedstat, pressure, netstat, network, memory, filesystem, disk, and CPU metrics are first marked as droppable
- only a curated allowlist is restored, such as key CPU, memory, disk IO, filesystem capacity, network traffic or error, and pressure metrics
- all histogram bucket series

Special handling:

- this component uses a temporary label `drop_node_exporter_metric`, then applies an allowlist, and finally drops only the series still marked with `1`

### Prometheus Operator

Config:

- [prometheus-operator.yaml](../../configs/pipelines/metric-drop/prometheus-operator.yaml)

Dropped metric types:

- all histogram bucket series
- generic `go_*` and `process_*`
- build, feature gate, and kubelet managed resource metadata
- Kubernetes client latency and rate limiter metrics
- successful `2xx` and `3xx` client request counters filtered by `status_code`
- list, node sync, reconcile, trigger, sync, and workqueue internal metrics
- sync success series filtered by `status=ok`

## Drop Method Summary

The repository currently uses four main rule styles.

### 1. Drop By Metric Name

```yaml
- action: drop
  regex: "go_.*"
  sourceLabels: [__name__]
```

This is the default style for dropping a whole metric family.

### 2. Drop By Metric Name Plus Label Value

```yaml
- action: drop
  separator: ";"
  regex: "^prometheus_operator_kubernetes_client_http_requests_total;(2|3)..$"
  sourceLabels: [__name__, status_code]
```

This is used when only part of one metric should be removed, such as:

- only success HTTP classes
- only `status=ok`
- only selected histogram buckets by `le`

### 3. Mark Then Drop

```yaml
- sourceLabels: [__name__]
  regex: "node_memory_.*|node_disk_.*"
  targetLabel: "drop_node_exporter_metric"
  replacement: "1"
  action: replace
```

This is used by `node-exporter` to implement a broad drop list with an explicit keep list.

### 4. One Component With Multiple Rule Blocks

`kubelet` uses three separate blocks:

- container metrics: `cAdvisorMetricRelabelings`
- kubelet metrics: `metricRelabelings`
- probe metrics: `probesMetricRelabelings`
