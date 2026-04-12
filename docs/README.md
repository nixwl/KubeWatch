# KubeWatch Documentation Guide

All documentation in this repository should be written in English.

This guide explains:

1. What each documentation folder is for
2. The complete recommended reading order

## Folder Purpose Overview

The canonical folder order is:

`deploy -> install -> metrics -> alerts -> workload -> traffics -> anomaly`

In this repository, the actual metrics folder path is `metric/`.

- `deploy/`: cluster and base infrastructure deployment (Kubernetes, storage, DNS, InfluxDB)
- `install/`: platform/component installation on top of the deployed clusters
- `metric/` (metrics): metric filtering and aggregation pipeline
- `alerts/`: alerting integration and setup
- `workload/`: stateful services and application workloads
- `traffics/`: workload traffic generation design and scripts
- `anomaly/`: ChaosBlade-based fault injection playbooks

Supporting folders:

- `export/`: data export references (for example, AlertSnitch persistence export)

## Complete Reading Order (Reordered)

### 1) Deploy

1. [`deploy/00-Kubernetes_Deployment.md`](deploy/00-Kubernetes_Deployment.md) — bootstrap K3s clusters and base runtime prerequisites
2. [`deploy/01-NFS_Deployment.md`](deploy/01-NFS_Deployment.md) — provide shared storage and dynamic provisioning
3. [`deploy/02-DNS_Deployment.md`](deploy/02-DNS_Deployment.md) — establish internal DNS and name resolution
4. [`deploy/07-InfluxDB_Deployment.md`](deploy/07-InfluxDB_Deployment.md) — deploy time-series storage backend

### 2) Install

5. [`install/03-CertManager_Install.md`](install/03-CertManager_Install.md) — install certificate manager and issuer workflow
6. [`install/05-PrometheusStack-Install.md`](install/05-PrometheusStack-Install.md) — install Prometheus/Grafana/Alertmanager stack
7. [`install/06-Alertsnitch-Install.md`](install/06-Alertsnitch-Install.md) — install alert persistence service
8. [`install/08-Telegraf-Install.md`](install/08-Telegraf-Install.md) — install telemetry agent and pipeline integration
9. [`install/04-Rancher-Install.md`](install/04-Rancher-Install.md) — install management plane for multi-cluster operations
10. [`install/21-Chaosblade-Install.md`](install/21-Chaosblade-Install.md) — prepare tooling for anomaly experiments

### 3) Metrics (`metric/`)

11. [`metric/09-MetricsDrop-Process.md`](metric/09-MetricsDrop-Process.md) — define metric dropping strategy
12. [`metric/10-MetricsAggregate-Process.md`](metric/10-MetricsAggregate-Process.md) — define metric aggregation strategy

### 4) Alerts

13. [`alerts/11-Alerts-Setup.md`](alerts/11-Alerts-Setup.md) — configure alerting rules and routing

### 5) Workload

14. [`workload/11-MySQL-Deploy.md`](workload/11-MySQL-Deploy.md) — deploy MySQL foundation service
15. [`workload/12-Redis-Deploy.md`](workload/12-Redis-Deploy.md) — deploy Redis and HA/sentinel setup
16. [`workload/13-Minio-Deploy.md`](workload/13-Minio-Deploy.md) — deploy object storage service
17. [`workload/14-PostgreSQL-Deploy.md`](workload/14-PostgreSQL-Deploy.md) — deploy PostgreSQL service
18. [`workload/15-Garage-Deploy.md`](workload/15-Garage-Deploy.md) — deploy Garage object storage gateway
19. [`workload/16-Gitea-Deploy.md`](workload/16-Gitea-Deploy.md) — deploy Gitea application
20. [`workload/18-Zot-Deploy.md`](workload/18-Zot-Deploy.md) — deploy Zot image registry
21. [`workload/19-Wiki-Deploy.md`](workload/19-Wiki-Deploy.md) — deploy Wiki.js application
22. [`workload/20-RequestTracker-Deploy.md`](workload/20-RequestTracker-Deploy.md) — deploy Request Tracker service
23. [`workload/17-FluentBit-Deploy.md`](workload/17-FluentBit-Deploy.md) — enable workload log shipping before traffic and anomaly tests

### 6) Traffics

24. [`traffics/00-gitea-traffics.md`](traffics/00-gitea-traffics.md) — Gitea traffic scenario design
25. [`traffics/01-zot-traffics.md`](traffics/01-zot-traffics.md) — Zot traffic scenario design
26. [`traffics/02-wiki-traffics.md`](traffics/02-wiki-traffics.md) — Wiki traffic scenario design
27. [`traffics/03-requesttrack-traffics.md`](traffics/03-requesttrack-traffics.md) — Request Tracker traffic scenario design

### 7) Anomaly

28. [`anomaly/00-node-inject.md`](anomaly/00-node-inject.md) — node-level fault injection workflow
29. [`anomaly/01-pod-inject.md`](anomaly/01-pod-inject.md) — pod-level fault injection workflow

## Optional Reference (Outside Core Path)

- [`export/00-export-alertsnitch.md`](export/00-export-alertsnitch.md) — AlertSnitch persistent alert data export reference
- [export_influxdb.sh](../scripts/export/export_influxdb.sh) — InfluxDB Full Buckets export
