# Prometheus Stack Install

Deploy `kube-prometheus-stack` on the `monitor` cluster to provide Prometheus, Alertmanager, and Grafana.

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

In the lab flow, the monitoring stack is used to:

- scrape the local `monitor` cluster
- expose Prometheus, Alertmanager, and Grafana through Traefik ingress
- persist TSDB and dashboard data on NFS-backed PVCs
- optionally scrape K3s control-plane metrics after enabling them explicitly

The examples in this document assume:

- monitor cluster control-plane node: `emanager1` (`192.168.52.9`)
- namespace: `monitor`
- Helm release name: `monitor`
- storage class: `nfs-client-storageclass`
- cert-manager issuer: `monitor-ca-issuer`

## Prerequisites

Complete the following first:

- [Kubernetes Deployment](../deploy/00-Kubernetes_Deployment.md)
- [NFS Deployment](../deploy/01-NFS_Deployment.md)
- [DNS Deployment](../deploy/02-DNS_Deployment.md)
- [Cert-Manager Install](./03-CertManager_Install.md)
- [Rancher Install](./04-Rancher-Install.md)

Next, configure the storage class by following the [guide](../../docs/deploy/01-NFS_Deployment.md) under the `EXAMPLE: Dynamic Provisioning in K3s` section."

related Yaml:

1. [rbac](../../configs/pipelines/prometheus_stack-install/monitor-rbac.yaml)
2. [provisioner](../../configs/pipelines/prometheus_stack-install/monitor-provisioner.yaml)
3. [storageclass](../../configs/pipelines/prometheus_stack-install/monitor-storageclass.yaml)

## Install kube-prometheus-stack On Monitor Cluster

### 1. Add the Helm Repository

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community/kube-prometheus-stack
```

Installing via the Rancher Web UI's Apps & Marketplace and then exporting the values.yaml for modification has proven in our testing to avoid various unexpected issues.

> using namspace: `monitor`

```sh
# On Monitor Cluster
helm list -A | grep kube-prometheus-stack
helm get values monitor-stack \
  -n monitor \
  --all \
  -o yaml > monitor-kube-prometheus-stack-values.yaml
```

> [kube-prometheus-stack-values.yaml](../../configs/pipelines/prometheus_stack-install/monitor-kube-prometheus-stack-values.yaml)

### 2. Config AlertManager

Complete the basic [configuration](../../configs/pipelines/prometheus_stack-install/monitor-alertmanager-basic.yaml) changes in the downloaded `monitor-kube-prometheus-stack-values.yaml` file.

```Yaml
alertmanager:
  alertmanagerSpec:
    # config exteranl access URL
    externalUrl: "https://alertmanager.example.com/"
    scheme: "http"
    # config resource limitition
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
    # storge configuration
    storage:
      volumeClaimTemplate:
        metadata:
          name: alertmanager-pv
        spec:
          storageClassName: nfs-client-storageclass
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
    # definition of PersistentVolumeClaim retention policy, default is retain(not delete)
    persistentVolumeClaimRetentionPolicy:
      whenDeleted: Retain
      whenScaled: Retain
```

Next, configure the alert receivers. [alertmanager-alerts.yaml](../../configs/pipelines/prometheus_stack-install/monitor-alertmanager-alerts.yaml)

Next, we need to configure the [Ingress](../../configs/pipelines/prometheus_stack-install/monitor-alertmanager-ingress.yaml) so that Alertmanager is accessible from both inside and outside the cluster.

```Yaml
alertmanager:
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: monitor-ca-issuer
    enabled: true
    hosts:
      - alertmanager.example.com
    ingressClassName: "traefik"
    labels: {}
    paths:
      - /
    tls:
      - secretName: alertmanager-general-tls
        hosts:
          - alertmanager.example.com
```

Overwrite with the modified configuration and verify whether Alertmanager was successfully installed.

```sh
# upgrade kube-prometheus-stack
helm upgrade monitor kube-prometheus/kube-prometheus-stack \
  -n monitor \
  -f monitor-kube-prometheus-stack-values.
# visit https://alertmanager.example.com
```

More configuration details can be found under the alertmanager section in the [`monitor-kube-prometheus-stack-values.yaml`](../../configs/pipelines/prometheus_stack-install/monitor-kube-prometheus-stack-values.yaml) file, which is the configuration file from our initial deployment of the Prometheus monitoring stack on the monitor cluster.

### 3. Config Grafana

First, configure the resource limits for basic components. Refer to [grafana-basic.yaml](../../configs/pipelines/prometheus_stack-install/monitor-grafana-basic.yaml).

```sh
helm upgrade monitor kube-prometheus/kube-prometheus-stack \
  -n monitor \
  -f monitor-kube-prometheus-stack-values.yaml
```

### 4. Config Kubernute Control-Plane

First, configure kube-state-metrics

```Yaml
kube-state-metrics:
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 300m
      memory: 256Mi
```

Then, disable kubeDns and kubeEtcd

```Yaml
kubeDns:
  enabled: false
kubeEtcd:
  enabled: false
```

Next, configure kubeControllerManager. KCM is a core component of the Kubernetes control plane (responsible for Deployment replica counts, Node status, Job control, etc.). This is a configuration snippet used to monitor the kube-controller-manager (KCM) component.

```Yaml
kubeControllerManager:
  enabled: true
  endpoints:
    - 192.168.52.9
  service:
    enabled: true
  port: 10257
  targetPort: 10257
```

- First, add the startup parameters in `/etc/systemd/system/k3s.service`, then restart the service.
  ```ini
  '--kube-controller-manager-arg=bind-address=0.0.0.0' \
  ```
- Then, restart and check the API.
  ```sh
  # reload and restart
  sudo systemctl daemon-reload
  sudo systemctl restart k3s.service
  # check
  ss -lntp | grep 10257
  curl -k https://192.168.52.9:10257/metrics -m 5 | head
  ```

Next, configure kubeProxy. kube-proxy is the network proxy that runs on every node, usually exposing its metrics on port 10249.

```Yaml
kubeProxy:
  enabled: true
  endpoints:
    - 192.168.52.9
  jobNameOverride: ""
  service:
    enabled: true
    port: 10249
    targetPort: 10249
```

Also add the startup parameters in `/etc/systemd/system/k3s.service`, then restart the service.

```ini
'--kube-proxy-arg=metrics-bind-address=0.0.0.0' \
```

Next, configure kubeScheduler.

```Yaml
kubeScheduler:
  enabled: true
  endpoints:
    - 192.168.52.9
  service:
    port: 10259
    targetPort: 10259
```

Also add the startup parameters in `/etc/systemd/system/k3s.service`, then restart the service.

```ini
'--kube-scheduler-arg=bind-address=0.0.0.0' \
```

```sh
helm upgrade monitor kube-prometheus/kube-prometheus-stack \
  -n monitor \
  -f monitor-kube-prometheus-stack-values.yaml
```

> **Troubleshot**:
>
> ```sh
> root@emanage1:/data/nfs-conf/kube-prometheus-stack# helm upgrade monitor kube-prometheus/kube-prometheus-stack \
>   -n monitor \
>   -f kube-prometheus-stack-values.yaml
> Error: UPGRADE FAILED: Unable to continue with update: Endpoints "monitor-kube-prometheus-st-kube-controller-manager" in namespace "kube-system" exists and cannot be imported into the current release: invalid ownership metadata; annotation validation error: missing key "meta.helm.sh/release-name": must be set to "monitor"; annotation validation error: missing key "meta.helm.sh/release-namespace": must be set to "monitor"
> ```
>
> **Fixed**:
>
> ```sh
> kubectl -n kube-system annotate endpoints monitor-kube-prometheus-st-kube-controller-manager \
>   meta.helm.sh/release-name=monitor \
>   meta.helm.sh/release-namespace=monitor \
>   --overwrite
> kubectl -n kube-system annotate endpoints monitor-kube-prometheus-st-kube-proxy \
>   meta.helm.sh/release-name=monitor \
>   meta.helm.sh/release-namespace=monitor \
>   --overwrite
> kubectl -n kube-system annotate endpoints monitor-kube-prometheus-st-kube-scheduler \
>   meta.helm.sh/release-name=monitor \
>   meta.helm.sh/release-namespace=monitor \
>   --overwrite
> ```

### 5. Config Prometheus

First, configure the Prometheus Ingress.

> [prometheus-ingress.yaml](../../configs/pipelines/prometheus_stack-install/monitor-prometheus-ingress.yaml)

Then, configure some basic settings for Prometheus.

> [prometheus-basic.yaml](../../configs/pipelines/prometheus_stack-install/monitor-prometheus-basic.yaml)

### 6. Config node-exporter

```Yaml
prometheus-node-exporter:
  livenessProbe:
    failureThreshold: 3
    httpGet:
      httpHeaders: []
      scheme: http
    initialDelaySeconds: 0
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi
```

### 7. Config PrometheusOperator

prometheusOperator is a controller used to manage CRD objects such as Prometheus, Alertmanager, ServiceMonitor, PodMonitor, etc. The Admission Webhook component is used for creating and updating CRD objects within the cluster.

> [prometheus-operator-basic.yaml](../../configs/pipelines/prometheus_stack-install/monitor-prometheus-operator-basic.yaml)

## Install kube-prometheus-stack On Producer Cluster

### 1. Create Producer CA & CluserIssuer

Create a [producer-cluster_issuer.yaml](../../configs/pipelines/prometheus_stack-install/producer-cluster_issuer.yaml)

```sh
# create cluster issuer for CA
kubectl apply -f producer-cluster_issuer.yaml
```

Create a [producer-ca_certificate.yaml](../../configs/pipelines/prometheus_stack-install/producer-ca_certificate.yaml)

```sh
# create certificate for CA
kubectl apply -f producer-ca_certificate.yaml
```

Create a [producer-ca_issuer.yaml](../../configs/pipelines/prometheus_stack-install/producer-ca_issuer.yaml)

```sh
# create a CA Issuer
kubectl apply -f producer-ca_issuer.yaml
# check ca issuer
kubectl get clusterissuer
```

### 2. Export Default Configuration

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community/kube-prometheus-stack
```

Installing via the Rancher Web UI's Apps & Marketplace and then exporting the values.yaml for modification has proven in our testing to avoid various unexpected issues.

> using namspace: `monitor`

```sh
# On Monitor Cluster
helm list -A | grep kube-prometheus-stack
helm get values monitor-stack \
  -n monitor \
  --all \
  -o yaml > producer-kube-prometheus-stack-values.yaml
```

### 3. Modify Configuration

> **To reduce redundant metrics and improve the quality of monitoring metrics, we manually filtered out most of the useless metrics at the collection end.**

Disable the PrometheusRole in the kube-prometheus-stack of the Producer cluster.

```Yaml
defaultRules:
  create: false
```

Modify the `kube-state-metrics` configuration.

> [producer-kube_state_metrics.yaml](../../configs/pipelines/prometheus_stack-install/producer-kube_state_metrics.yaml)

Modify the `kubeApiServer` configuration.

> [producer-kube_apiserver.yaml](../../configs/pipelines/prometheus_stack-install/producer-kube_apiserver.yaml)

Modify the `kubeControllerManager` configuration.

> [producer-kube_controller_manager.yaml](../../configs/pipelines/prometheus_stack-install/producer-kube_controller_manager.yaml)

Similar to the deployment on the Monitor, you also need to add startup parameters to /`etc/systemd/system/k3s.service`.

```ini
'--kube-controller-manager-arg=bind-address=0.0.0.0' \
```

```sh
# reload and restart
sudo systemctl daemon-reload
sudo systemctl restart k3s.service
```

Modify the `kubeProxy` configuration.

> [producer-kube_proxy.yaml](../../configs/pipelines/prometheus_stack-install/producer-kube_proxy.yaml)

```ini
'--kube-proxy-arg=metrics-bind-address=0.0.0.0' \
```

```sh
# reload and restart
sudo systemctl daemon-reload
sudo systemctl restart k3s.service
```

Modify the `kubeScheduler` configuration.

> [producer-kube_scheduler.yaml](../../configs/pipelines/prometheus_stack-install/producer-kube_scheduler.yaml)

```ini
'--kube-scheduler-arg=bind-address=0.0.0.0' \
```

```sh
# reload and restart
sudo systemctl daemon-reload
sudo systemctl restart k3s.service
```

Modify the `kubelet` configuration.

> [producer-kubelet.yaml](../../configs/pipelines/prometheus_stack-install/producer-kubelet.yaml)

Modify the `prometheus` configuration.

> [producer-prometheus.yaml](../../configs/pipelines/prometheus_stack-install/producer-prometheus.yaml)

1. First, set labels for the nodes.
   ```sh
   kubectl get nodes --show-labels
   kubectl label node <node-name> node-role=worker
   kubectl label node <node-name> node-role=master
   ```
2. Second, for the remoteWrite section, connect to the monitor cluster and enable the remote write feature.
   ```Yaml
   prometheus:
     prometheusSpec:
        enableRemoteWriteReceiver: true
   ```
3. Third, exoprt Monitor CA cert to Producer.
   ```sh
   # 1. search Monitor CA cert
   kubectl get clusterissuer monitor-ca-issuer -o jsonpath='{.spec.ca.secretName}'
   # 2. check CA cert
   kubectl get secret -A | grep -w monitor-ca-secret
   # 3. export CA cert
   kubectl -n cert-manager get secret monitor-ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d > ca.crt
   mv ca.crt monitor-promtheus.crt
   ```
4. Next, create a Secret to mount this monitor-promtheus.crt onto the production cluster for verification.
   ```sh
   kubectl -n monitor create secret generic monitor-ca-secret --from-file=ca.crt=./monitor-promtheus.crt
   # check
   kubectl -n monitor get secret monitor-ca-secret -o yaml
   ```
5. Finally, adjust the kube-prometheus-stack configuration file for the Producer cluster and add the remote write address.
   ```yaml
   prometheus:
     agentMode: true
     replicaExternalLabelNameClear: true
     remoteWrite:
       - url: "https://prometheus.example.com/api/v1/write"
         tlsConfig:
           insecureSkipVerify: false
           serverName: "prometheus.example.com"
           ca:
             secret:
               name: monitor-ca-secret
               key: ca.crt
   ```

Modify the `node-exporter`configuration.

> [producer-node_exporter.yaml](../../configs/pipelines/prometheus_stack-install/producer-node_exporter.yaml)

Modify the `PrometheusOperator`configuration.

> [producer-prometheus_operator.yaml](../../configs/pipelines/prometheus_stack-install/producer-prometheus_operator.yaml)

Finally, restart the deployment

```sh
helm upgrade monitor kube-prometheus/kube-prometheus-stack \
  -n monitor \
  -f producer-kube-prometheus-stack-values.yaml
```

> **Troubleshot**
>
> ```logs
> time=2026-01-03T05:10:00.918Z level=WARN source=scrape.go:1941 msg="Error on ingesting out-of-order samples" component="scrape manager" scrape_pool=serviceMonitor/monitor/monitor-kube-prometheus-st-kubelet/1 target=https://192.168.52.3:10250/metrics/cadvisor num_dropped=62
> ```
>
> First, check the UI to see if it's an NTP issue. Look directly at the node-exporter metrics: `node_timex_sync_status` and `node_timex_offset_seconds`. Then, check for duplicate scrapes and dropped critical metrics.
>
> ```promehteus
> # prometheus web ui query
> count by (instance) (up{metrics_path="/metrics/cadvisor"})
> count by (instance) (container_cpu_usage_seconds_total{metrics_path="/metrics/cadvisor"})
> ```
>
> Next, check for out-of-order issues. You'll need to enter the Prometheus container—specifically the agent container—to investigate.
>
> ```sh
> kubectl -n monitor exec -it prom-agent-monitor-kube-prometheus-st-0 -- sh
> wget -qO- http://127.0.0.1:9090/metrics | grep -E "prometheus_target_scrapes_sample_out_of_order_total|prometheus_tsdb_out_of_order_samples_total" || true
> ```
>
> Found that `prometheus_target_scrapes_sample_out_of_order_total > 0`. However, after checking the Prometheus logs/metrics multiple times, no further increase was detected.
>
> ```sh
> kubectl get pod -A | egrep 'prometheus|prom-agent|kube-prometheus' | head -n 30
> kubectl -n <ns> exec -it <prom-pod> -- sh
> wget -qO- http://127.0.0.1:9090/metrics | egrep "^prometheus_target_scrapes_sample_(out_of_order|duplicate_timestamp)_total "
> ```
>
> This indicates that sample dropping is occurring at the collection side. Based on the following checks, we found that a significant amount of data loss is happening in cAdvisor.
> Check the error messages again.
>
> ```sh
> kubectl -n monitor logs prom-agent-monitor-kube-prometheus-st-0 -c prometheus --since=2h | egrep -i "remote write|remote_storage|server returned|status code|x509|tls|timeout|context deadline|out of order|too old|429|413|500|502|503|504" | tail -n 10
> ```
>
> Found that disk write requests were rejected during ingestion.
>
> ```log
> time=2026-01-03T09:47:48.599Z level=ERROR source=queue_manager.go:1709 msg="we got 2xx status code from the Receiver yet statistics indicate some data was not written; investigation needed" component=remote remote_name=27ce1d url=https://prometheus.example.com/api/v1/write failedSampleCount=885 failedHistogramCount=0 failedExemplarCount=0
> ```
>
> Prometheus 3.8.0 has a known issue: the remote-write receiver returns incorrect response headers during the PRW (Prometheus Remote Write) 1.0 flow. This causes the sender to misinterpret the response as a partial write, leading to the observed error logs and an increase in failure metrics. This issue is fixed in version 3.8.1.
>
> ```sh
> # check sender (prom-agent)
> kubectl -n monitor exec -it prom-agent-monitor-kube-prometheus-st-0 -c prometheus -- prometheus --version
> # check receiver
> kubectl -n <receiver-ns> exec -it <receiver-pod> -c prometheus -- prometheus --version
> ```
>
> The modification method is shown below:
>
> ```Yaml
> image:
>   pullPolicy: IfNotPresent
>   registry: quay.io
>   repository: prometheus/prometheus
>   sha: ""
>   tag: v3.8.1
> overrideHonorTimestamps: true
> ```
