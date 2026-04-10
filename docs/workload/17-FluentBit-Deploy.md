# Fluent Bit Deployment

It uses Fluent Bit as a DaemonSet-based log collector on K3s. We route pod logs and selected node logs to a MinIO bucket through the Fluent Bit S3 output plugin, with a shared PVC used as the local buffer store. The same notes also include an optional MinIO export workflow for archiving retained log objects to a filesystem-backed PVC.

Fluent Bit is an ultra-lightweight, high-performance log processor and forwarder designed specifically for cloud-native environments, edge computing, and resource-constrained scenarios. It features a three-tier architecture:

- Input (Data Sources): Supports 80+ sources, including Kubernetes container logs, Syslog, HTTP, MQTT, Windows Events, and Prometheus metrics.

  > K8s Feature: Automatically injects Pod metadata (Namespace/Labels/Annotations).

- Filter (Processing Layer): Core capabilities include log parsing (JSON/Regex), field modification, data masking, sampling, and K8s metadata enrichment.

  > Key Plugins: kubernetes (automatically associates Pod info), modify (field operations), grep (filtering), and throttle (rate limiting).

- Output (Destinations): Seamlessly integrates with 50+ targets, such as Loki, Elasticsearch, Splunk, Prometheus Remote Write, S3, and Kafka.
  > Smart Retries: Supports checkpointing (resuming from breakpoints) and backpressure control (preventing memory overflow during downstream failures).

Deployment: Typically deployed as a DaemonSet, it automatically collects all container logs without requiring Sidecar injection.

## Prerequisites

- A Kubernetes namespace named `logging`
- A writable storage class such as `nfs-client-storageclass`
- Worker nodes labeled with `node-role=worker`
- A working MinIO deployment in the `database` namespace
- A `k8s-logs` bucket in MinIO
- A MinIO user or service account for Fluent Bit S3 writes

## Architecture Overview

- Fluent Bit runs as a DaemonSet so every node collects logs locally.
- Pod logs are read from `/var/log/pods`.
- Node-level logs are collected from journald, kernel `kmsg`, and selected host log files.
- Fluent Bit writes compressed log objects to the MinIO bucket `k8s-logs`.
- A shared PVC stores Fluent Bit local buffers and S3 staging data.

## Prepare MinIO For Log Storage

### 1. Create Bucket

A dedicated setup job is used to create the `k8s-logs` bucket, enable versioning, and apply lifecycle-management rules.

> [minio-buckets.yaml](../../configs/pipelines/workload/minio-buckets.yaml)

The job logic does three things:

- Creates the bucket if it does not exist.
- Enables versioning.
- Adds lifecycle rules for current and non-current object expiration.

Use a temporary MinIO client pod to verify the bucket, versioning, and lifecycle rules.

```sh
NS=database
SVC=minio
ROOT_SECRET=minio-auth
ROOT_USER="$(kubectl -n "$NS" get secret "$ROOT_SECRET" -o jsonpath='{.data.rootUser}' | base64 -d)"
ROOT_PASS="$(kubectl -n "$NS" get secret "$ROOT_SECRET" -o jsonpath='{.data.rootPassword}' | base64 -d)"

kubectl -n "$NS" run mc-check --rm -it --restart=Never \
  --image=bitnamilegacy/minio-client:2025.7.21-debian-12-r2 \
  --env="SVC=$SVC" \
  --env="ROOT_USER=$ROOT_USER" \
  --env="ROOT_PASS=$ROOT_PASS" \
  --command -- /bin/sh
```

Inside the shell:

```sh
set -e
mc alias set local "http://$SVC:9000" "$ROOT_USER" "$ROOT_PASS"
mc ls local | grep -E '^.*\sk8s-logs/$'
mc version info local/k8s-logs
mc ilm rule ls local/k8s-logs
```

### 2. Export Bukcet

Also include a separate export workflow that copies retained MinIO log objects to a filesystem-backed PVC for offline access or further processing.

First, create the [export PVC](../../configs/pipelines/workload/minio-export-pvc.yaml)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: logs-export-pvc
  namespace: database
spec:
  storageClassName: nfs-client-storageclass
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Next, We create a dedicated MinIO user named `exporter`, attach the `logs-rw` policy, generate a service-account token, and store that token in a secret named [minio-export](../../configs/pipelines/workload/minio-export-secret.yaml).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-export
  namespace: database
type: Opaque
stringData:
  MINIO_ACCESS_KEY: "<export-access-key>"
  MINIO_SECRET_KEY: "<export-secret-key>"
```

Then create a [export configmap](../../configs/pipelines/workload/minio-export-configmap.yaml)

- MinIO endpoint and bucket
- Prefix to export, for example `k8s/nodes`
- Output directory path on the export PVC
- UTC-day export mode and day offset
- File name pattern, typically `*.gz`

Apply it:

```sh
kubectl apply -f minio-export-secret.yaml
kubectl apply -f minio-export-pvc.yaml
kubectl apply -f minio-export-configmap.yaml
```

Configure the export operation as a [Job](../../configs/pipelines/workload/minio-exports-job.yaml) or a [CronJob](../../configs/pipelines/workload/minio-exports-cronjob.yaml).

Run the one-time export:

```sh
kubectl apply -f minio-exports-job.yaml
```

Or enable the daily export schedule:

```sh
kubectl apply -f minio-exports-cronjob.yaml
```

## Create RBAC For Fluent Bit

Fluent Bit needs read access to node, pod, and namespace metadata so it can enrich records with Kubernetes context.

> [fluent-bit-rbac.yaml](../../configs/pipelines/workload/fluent-bit-rbac.yaml)

Apply it:

```sh
kubectl apply -f fluent-bit-rbac.yaml
```

## Create The Shared Buffer PVC

The DaemonSet uses a shared RWX PVC for tail databases, temporary spool files, and the S3 output plugin store directories.

> [fluent-bit-pvc.yaml](../../configs/pipelines/workload/fluent-bit-pvc.yaml)

Apply it:

```sh
kubectl apply -f fluent-bit-pvc.yaml
```

## Create The MinIO Credentials Secret

We create a MinIO service account for the `fluentbit` user, then mount the access key and secret key into the DaemonSet.

First generate a service account in MinIO:

```sh
mc alias set myminio "http://minio.database.svc.cluster.local:9000" "$ROOT_USER" "$ROOT_PASS"
mc ls myminio
mc ls myminio/k8s-logs | head
mc admin user svcacct add myminio fluentbit
```

Then create the [Kubernetes secret](../../configs/pipelines/workload/fluent-bit-s3_secret.yaml) in the `logging` namespace:

Apply it:

```sh
kubectl apply -f fluent-bit-s3_secret.yaml
```

## Configure Fluent Bit

The source configuration reads three log categories:

- Pod logs from `/var/log/pods/*/*/*.log`
- Node service logs from journald
- Node host logs from files such as `syslog`, `messages`, `daemon.log`, and `docker.log`

For pod logs, the config uses the `docker` parser because K3s plus Docker or `cri-dockerd` frequently exposes `/var/log/pods/.../*.log` as symlinks to Docker JSON log files.

The source configuration applies:

- A Lua filter to extract namespace, pod, UID, and container name from the pod-log file path
- A `modify` filter to drop the Docker `stream` field
- A `modify` filter to tag node logs with `node_source`
- A `grep` filter to keep only relevant node log lines for `k3s`, `docker`, `dockerd`, `cri-dockerd`, and `kubelet`

Two S3 outputs are configured:

- Pod logs are written to `/k8s/pods/${NODE_NAME}/...`
- Node logs are written to `/k8s/nodes/${NODE_NAME}/...`

Both outputs:

- Use the MinIO S3-compatible endpoint
- Compress data with `gzip`
- Keep local staging files under `/buffers/s3/...`
- Preserve data ordering
- Disable retry limits so uploads continue retrying during downstream failures

Apply the Fluent Bit configuration:

> [fluent-bit-configmap.yaml](../../configs/pipelines/workload/fluent-bit-configmap.yaml)

```sh
kubectl apply -f fluent-bit-configmap.yaml
```

## Deploy The DaemonSet

We use a privileged DaemonSet because it mounts host log paths, journald directories, and `/dev/kmsg`. It also uses an init container to create node-specific buffer directories inside the shared PVC.

Key runtime characteristics:

- Image: `fluent/fluent-bit:4.2.2`
- Metrics endpoint: `:2020`
- Buffer mount: `/buffers`
- Pod log mount: `/var/log/pods`
- Docker container log mount: `/var/lib/docker/containers`
- Journald mounts: `/run/log/journal` and `/var/log/journal`
- Host file-log mount: `/host/var/log`

Apply the [DaemonSet](../../configs/pipelines/workload/fluent-bit-daemonset.yaml):

```sh
kubectl apply -f fluent-bit-daemonset.yaml
```

## Verify The Deployment

Check logs first to confirm there are no obvious parsing, S3, or credential errors.

```sh
kubectl -n logging logs -l app=fluent-bit --tail=120
```

Then inspect one pod to confirm the secret injection, buffer PVC, and host-path mounts are present.

```sh
POD=$(kubectl -n logging get pod -l app=fluent-bit -o jsonpath='{.items[0].metadata.name}')
kubectl -n logging describe pod "$POD"
```

The source notes specifically verify:

- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` come from `minio-fluentbit-s3-credentials`
- `/buffers` is mounted from the shared PVC
- `/var/log/pods`, `/var/lib/docker/containers`, `/run/log/journal`, `/var/log/journal`, and `/dev/kmsg` are mounted correctly
- The init container completed successfully
