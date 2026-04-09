# Telegraf Install

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

To write data to InfluxDB v2, it must be routed through Telegraf. You need to deploy Telegraf in the monitor environment and configure the Prometheus server to forward its monitoring data to Telegraf, which then writes the data into InfluxDB.

## Prerequisites

Complete the following first:

- [Kubernetes Deployment](../deploy/00-Kubernetes_Deployment.md)
- [NFS Deployment](../deploy/01-NFS_Deployment.md)
- [DNS Deployment](../deploy/02-DNS_Deployment.md)
- [InfluxDB Deployment](../deploy/07-InfluxDB_Deployment.md)
- [Prometheus Stack Install](./05-PrometheusStack-Install.md)

## Install Telegraf On Monitor Cluster

Add the influx Helm chart and install telegraf

```sh
helm repo add influxdata https://helm.influxdata.com/
helm repo update
helm upgrade --install telegraf influxdata/telegraf -n monitor
```

## Configure Telegraf

You nedd to configure an access token in InfluxDB for remote writes. This can be done directly in the UI. Next, export and modify the current Helm configuration.

```sh
helm -n monitor list
helm -n monitor get values telegraf --all -o yaml > telegraf.yaml
```

> [telegraf.yaml](../../configs/pipelines/telegraf-install/telegraf.yaml)

First, configure the collection and refresh behavior for Telegraf itself.

```Yaml
config:
  agent:
    collection_jitter: 1s
    debug: false
    flush_interval: 10s
    flush_jitter: 1s
    hostname: $HOSTNAME
    interval: 10s
    logfile: ""
    metric_batch_size: 5000
    metric_buffer_limit: 20000
    omit_hostname: true
    precision: ""
    quiet: false
    round_interval: true
```

Next, configure the data input for Telegraf.

```Yaml
config:
  inputs:
    - http_listener_v2:
        service_address: ":1234"
        paths:
        - "/receive"
        data_format: "prometheusremotewrite"
  service:
    enabled: true
    type: ClusterIP
    ports:
        - name: remote-write
        port: 1234
        targetPort: 1234
        protocol: TCP
```

Next, return to [monitor-kube-prometheus-stack-values.yaml](../../configs/pipelines/prometheus_stack-install/monitor-kube-prometheus-stack-values.yaml) and add the remoteWrite configuration for Prometheus.

```Yaml
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: "http://telegraf.monitor.svc:1234/receive"
```

```sh
# update deployments
helm upgrade -n monitor telegraf influx/telegraf -f telegraf.yaml
helm upgrade monitor kube-prometheus/kube-prometheus-stack -n monitor -f monitor-kube-prometheus-stack-values.yaml
```

Next, configure the bucket settings for Telegraf's output.

```Yaml
config:
  outputs:
    - influxdb_v2:
      urls: ["http://192.168.52.8:8086"]
      token: "$INFLUX_TOKEN"
      organization: "data-center"
      bucket: "monitor"
        tagpass:
          cluster: ["monitor"]
    - influxdb_v2:
      urls: ["http://192.168.52.8:8086"]
      token: "$INFLUX_TOKEN"
      organization: "data-center"
      bucket: "producer"
        tagpass:
          cluster: ["producer"]
```

$INFLUX_TOKEN needs to be injected via a secretKeyRef.

```sh
kubectl -n monitor create secret generic remoterw-token --from-literal=INFLUX_TOKEN='<your_token>'

```

```Yaml
env:
  - name: HOSTNAME
    value: telegraf-polling-service
  - name: INFLUX_TOKEN
    valueFrom:
      secretKeyRef:
        name: remoterw-token
        key: INFLUX_TOKEN
```
