# KubeWatch 👀

KubeWatch is a repository for building a reproducible Kubernetes monitoring data collection pipeline. It documents and organizes the deployment scripts, configuration files, workload setup, traffic generation templates, anomaly injection playbooks, monitoring rules, and data export steps required to construct Kubernetes runtime monitoring datasets.

The repository is intended for users who want to reproduce the KubeWatch data collection workflow rather than only inspect final dataset files. It provides an end-to-end process for setting up Kubernetes clusters, deploying monitored services, generating workloads, injecting anomalies, collecting metrics and alerts, and exporting the collected data for downstream processing.

## 🎯 Purpose

KubeWatch supports the construction of monitoring datasets for anomaly detection in Kubernetes environments. The pipeline is designed to collect runtime telemetry from multiple Kubernetes observation layers, including nodes, pods, and the control plane, while recording controlled anomaly provenance and alert events.

The main goals are:

- Build a reproducible Kubernetes monitoring testbed.
- Deploy representative cloud-native workload services.
- Generate controlled application traffic.
- Inject controlled node-level and pod-level anomalies.
- Collect runtime metrics, derived KPIs, alerts, and injection records.
- Export monitoring data for offline alignment, labeling, and benchmark construction.

## 🧭 Pipeline Overview

KubeWatch follows a staged construction workflow:

```text
deploy -> install -> metric -> alerts -> workload -> traffics -> anomaly -> export
```

The stages are organized as follows:

1. **Deploy infrastructure**  
   Bootstrap Kubernetes clusters and external infrastructure such as shared storage, DNS, and time-series storage.

2. **Install platform components**  
   Install the monitoring, alerting, telemetry forwarding, management, and anomaly injection components.

3. **Configure metrics**  
   Define metric filtering rules and KPI aggregation rules for the monitoring pipeline.

4. **Configure alerts**  
   Define alerting rules and alert persistence mechanisms.

5. **Deploy workload services**  
   Deploy application workloads and their backend dependencies.

6. **Generate workload traffic**  
   Use traffic scripts and templates to exercise deployed services under controlled workload intensities.

7. **Inject anomalies**  
   Use ChaosBlade-based playbooks to inject node-level and pod-level anomalies.

8. **Export data**  
   Export alert records and monitoring data for offline dataset assembly.

## 🗂️ Repository Structure

```text
KubeWatch/
├── assets/                  # Figures and visual assets
├── configs/                 # Environment, pipeline, traffic, and anomaly configurations
├── data/                    # Dataset files, manifests, or generated data outputs
├── docs/                    # Step-by-step construction documentation
│   ├── deploy/              # Cluster and base infrastructure deployment
│   ├── install/             # Platform and component installation
│   ├── metric/              # Metric filtering and KPI aggregation setup
│   ├── alerts/              # Alerting rules and alert persistence setup
│   ├── workload/            # Workload and backend service deployment
│   ├── traffics/            # Application traffic generation scenarios
│   ├── anomaly/             # ChaosBlade anomaly injection workflows
│   └── export/              # Data export references
├── examples/                # Example YAML files
├── scripts/                 # Automation scripts
├── src/                     # Processing and utility code
├── wiki/                    # Additional notes
├── LICENSE
└── README.md
```

## 🏗️ Testbed Design

The data collection pipeline is built on a dual-cluster Kubernetes testbed.

- The **producer cluster** runs the monitored workload services and receives controlled anomaly injections.
- The **monitor cluster** hosts workload generation, monitoring, alerting, telemetry forwarding, and event recording components.
- External machines provide supporting services such as DNS, shared storage, load balancing, and persistent telemetry storage.

This separation reduces measurement interference between the monitored runtime and the monitoring pipeline. It also keeps the monitoring and storage components available when anomalies are injected into the producer cluster.

## 📚 Documentation Order

The recommended reading and execution order is defined by the documentation under `docs/`.

### 🚀 1. Deploy

Use the deployment documents to bootstrap the Kubernetes clusters and external infrastructure.

```text
docs/deploy/00-Kubernetes_Deployment.md
docs/deploy/01-NFS_Deployment.md
docs/deploy/02-DNS_Deployment.md
docs/deploy/07-InfluxDB_Deployment.md
```

These steps prepare the Kubernetes runtime, shared storage, internal name resolution, and persistent time-series storage.

### 🔧 2. Install

Install the platform components required by the data collection pipeline.

```text
docs/install/03-CertManager_Install.md
docs/install/05-PrometheusStack-Install.md
docs/install/06-Alertsnitch-Install.md
docs/install/08-Telegraf-Install.md
docs/install/04-Rancher-Install.md
docs/install/21-Chaosblade-Install.md
```

This stage installs the Prometheus-based monitoring stack, alert persistence service, telemetry forwarding component, management plane, and ChaosBlade anomaly injection tooling.

### 📈 3. Configure Metrics

Configure the metric filtering and aggregation pipeline.

```text
docs/metric/09-MetricsDrop-Process.md
docs/metric/10-MetricsAggregate-Process.md
```

The metric pipeline keeps raw monitoring data and also derives operational KPIs through Prometheus recording rules. These KPIs summarize selected raw metrics over aggregation windows and provide a stable view of runtime behavior.

### 🚨 4. Configure Alerts

Configure alerting rules and alert routing.

```text
docs/alerts/11-Alerts-Setup.md
```

Alert events provide runtime context for abnormal states and are later aligned with anomaly injection records and monitoring time series.

### 🧱 5. Deploy Workloads

Deploy backend services and monitored application workloads.

```text
docs/workload/11-MySQL-Deploy.md
docs/workload/12-Redis-Deploy.md
docs/workload/13-Minio-Deploy.md
docs/workload/14-PostgreSQL-Deploy.md
docs/workload/15-Garage-Deploy.md
docs/workload/16-Gitea-Deploy.md
docs/workload/18-Zot-Deploy.md
docs/workload/19-Wiki-Deploy.md
docs/workload/20-RequestTracker-Deploy.md
docs/workload/17-FluentBit-Deploy.md
```

The workload layer includes representative self-hosted DevOps services and their dependencies, including databases, caches, object storage systems, registry services, documentation services, ticket management services, and log shipping components.

### 🔁 6. Generate Traffic

Use the traffic documents to generate controlled application workloads.

```text
docs/traffics/00-gitea-traffics.md
docs/traffics/01-zot-traffics.md
docs/traffics/02-wiki-traffics.md
docs/traffics/03-requesttrack-traffics.md
```

Traffic generation exercises the deployed workload services through application-level operations. These workload scripts are used to introduce controlled runtime variation before and during anomaly injection.

### ⚡ 7. Inject Anomalies

Use the anomaly injection documents to run controlled anomaly cases.

```text
docs/anomaly/00-node-inject.md
docs/anomaly/01-pod-inject.md
```

KubeWatch injects anomalies at two scopes:

- **Node-level anomalies** perturb shared runtime conditions and may affect multiple co-located pods.
- **Pod-level anomalies** target individual workload instances and primarily affect the target pods.

The control plane is not used as a direct injection target. It is retained as an observation layer for secondary orchestration responses, such as scheduling-related state changes and object state changes.

### 📤 8. Export Data

Use the export documents and scripts to export persistent monitoring and alert data.

```text
docs/export/00-export-alertsnitch.md
scripts/export/export_influxdb.sh
```

The exported data can be used for offline alignment, anomaly window construction, label generation, and benchmark preparation.

## 📊 Data Collected by the Pipeline

The KubeWatch pipeline collects two main categories of data.

### 📉 Monitoring Time Series

Monitoring time series describe Kubernetes runtime states across node, pod, and control plane observation layers.

- **Node metrics** describe cluster resource conditions, including CPU usage, memory usage, disk I/O, and network traffic.
- **Pod metrics** describe workload instance behavior, including CPU and memory usage, pod states, restarts, and lifecycle information.
- **Control plane metrics** describe orchestration-related states, including pod phases, readiness conditions, scheduling-related status, and object state changes.

### 🧾 Event Records

Event records provide temporal context for aligning anomalies with runtime behavior.

- **Injection records** describe each controlled anomaly run, including start time, end time, injection type, target scope, target objects, and execution status.
- **Alert records** describe alert events from the monitoring stack, including alert names, firing and recovery times, severity levels, affected instances, and metadata.

## 🧩 Dataset Assembly

After monitoring time series and event records are exported, the offline assembly process aligns metrics, KPIs, alert records, and injection records on a unified timeline.

The assembly process typically includes:

1. Normalize timestamps across monitoring data and event records.
2. Align raw metrics, KPIs, alert records, and injection records.
3. Use injection records to define candidate anomaly windows.
4. Use alert firing and recovery times to refine anomaly window extent.
5. Project refined anomaly windows onto the sampling timeline.
6. Generate anomaly labels.
7. Produce training data, test data, and test label files.

## 🧪 Benchmark View

The benchmark view uses KPI time series as model input. The data are organized by Kubernetes observation layer:

- Node benchmark.
- Pod benchmark.
- Control plane benchmark.

For each observation layer, subset KPI time series are appended in a fixed order to form a layer-level benchmark sequence while preserving the original KPI dimensionality of each subset. Subset boundaries should be retained to avoid treating transitions between monitored entities as anomalous samples.

The benchmark follows an unsupervised anomaly detection protocol:

- Labels are not used during training.
- Normal-period data are used for training.
- Data collected during controlled anomaly injections are used for testing.
- A sample is labeled anomalous if its original timestamp falls within a refined anomaly window associated with the corresponding subset.

## ✅ Reproduction Checklist

Use the following checklist when reproducing the data collection pipeline:

- [ ] Deploy Kubernetes clusters.
- [ ] Configure NFS shared storage.
- [ ] Configure DNS and name resolution.
- [ ] Deploy InfluxDB.
- [ ] Install Cert Manager.
- [ ] Install Prometheus, Grafana, and Alertmanager.
- [ ] Install AlertSnitch.
- [ ] Install Telegraf.
- [ ] Install Rancher.
- [ ] Install ChaosBlade.
- [ ] Configure metric filtering rules.
- [ ] Configure KPI aggregation rules.
- [ ] Configure alerting rules.
- [ ] Deploy backend services.
- [ ] Deploy application workloads.
- [ ] Generate controlled application traffic.
- [ ] Execute node-level anomaly injection cases.
- [ ] Execute pod-level anomaly injection cases.
- [ ] Export monitoring data and alert records.
- [ ] Align metrics, alerts, and injection records.
- [ ] Generate labels and benchmark files.

## 📝 Notes

- The repository is organized as a construction workflow, not only as a final dataset archive.
- Paths and generated outputs may differ across deployments depending on the configured environment.
- Users should follow the documentation under `docs/` in the recommended order.
- Sensitive environment-specific values should be stored in local configuration files and should not be committed to the repository.

## 📌 Citation

If you use KubeWatch or its construction workflow in your research, please cite the corresponding paper:

## 📄 License

This repository is released under the Apache-2.0 License. See `LICENSE` for details.
