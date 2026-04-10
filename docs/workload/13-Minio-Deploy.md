# MinIO Deployment

It uses the Bitnami MinIO Helm chart and follows the source notes as a standalone, PVC-backed object-storage deployment with the MinIO console and provisioning enabled.

## Prerequisites

- A Kubernetes namespace named `database`
- A writable storage class such as `nfs-client-storageclass`
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine

## 1. Add The Helm Chart and Export Default Values

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo minio
# export values
helm show values bitnami/minio > minio-values.yaml
```

Use [`minio-values.yaml`](../../configs/pipelines/workload/minio-values.yaml) as the working configuration file.

Explicitly replace the default image with a `bitnamilegacy` image.

```yaml
image:
  registry: docker.io
  repository: bitnamilegacy/minio
  tag: 2025.7.23-debian-12-r3
  digest: ""
```

Then install Minio.

```sh
helm upgrade --install minio bitnami/minio \
  --version 17.0.21 \
  -n database \
  -f minio-values.yaml
```

## 2. Create The Required Secrets

Create one [secret](../../configs/pipelines/workload/minio-secret.yaml) for the MinIO root account and another one for provisioned application users.

```yaml
# Root Credentials
apiVersion: v1
kind: Secret
metadata:
  name: minio-auth
  namespace: database
type: Opaque
stringData:
  rootUser: admin
  rootPassword: "<password>"
---
#  Provisioned User Credentials
apiVersion: v1
kind: Secret
metadata:
  name: minio-provision-users
  namespace: database
type: Opaque
stringData:
  fluentbit-user: |
    username=fluentbit
    password=<password>
    disabled=false
    policies=logs-rw
    setPolicies=true
```

## 3. Configure The Basic Values File

We modified authentication, deployment mode, node scheduling, resources, persistence, console settings, provisioning, and the container image source.

```yaml
# !minio-values.yaml
# Base And Auth Configuration
global:
  imageRegistry: ""
  imagePullSecrets: []
  defaultStorageClass: "nfs-client-storageclass"
  security:
    allowInsecureImages: false
  compatibility:
    openshift:
      adaptSecurityContext: auto

diagnosticMode:
  enabled: false
  command:
    - sleep
  args:
    - infinity

auth:
  rootUser: ""
  rootPassword: ""
  existingSecret: "minio-auth"
  rootUserSecretKey: "rootUser"
  rootPasswordSecretKey: "rootPassword"
  forcePassword: false
  usePasswordFiles: true
  useSecret: true
  forceNewKeys: false
```

We use standalone mode and schedule the pod onto worker nodes, and we configured modest resource limits.

```yaml
# !minio-values.yaml
mode: standalone

nodeSelector:
  node-role: worker

resourcesPreset: "none"
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 1Gi

# pvc
persistence:
  enabled: true
  storageClass: "nfs-client-storageclass"
  mountPath: /bitnami/minio/data
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  annotations: {}
  existingClaim: ""
  selector: {}
  dataSource: {}

# network: disable the chart-managed network policy.
networkPolicy:
  enabled: false

# console configuration
console:
  enabled: true
  replicaCount: 1
  containerPorts:
    http: 9090
  resourcesPreset: "none"
  resources:
    requests:
      cpu: 25m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi
  nodeSelector:
    node-role: worker
  networkPolicy:
    enabled: false
```

## 4. Configure Provisioning

Provision a single bucket named `k8s-logs` and assign a `logs-rw` policy to an application user.

```yaml
# !minio-values.yaml
provisioning:
  enabled: true
  nodeSelector:
    node-role: worker
  users: []
    usersExistingSecrets:
      - minio-provision-users
  policies:
    - name: logs-rw
      statements:
        - effect: "Allow"
          resources:
            - "arn:aws:s3:::k8s-logs"
          actions:
            - "s3:GetBucketLocation"
            - "s3:ListBucket"
            - "s3:ListBucketMultipartUploads"
        - effect: "Allow"
          resources:
            - "arn:aws:s3:::k8s-logs/*"
          actions:
            - "s3:AbortMultipartUpload"
            - "s3:DeleteObject"
            - "s3:GetObject"
            - "s3:ListMultipartUploadParts"
            - "s3:PutObject"
  buckets:
    - name: "k8s-logs"
      region: "us-east-1"
      versioning: "Suspended"
```

## 5. Verify The Deployment

```sh
# verify basic resource
kubectl -n database get pvc | grep minio
kubectl -n database get pods -o wide | egrep -i 'minio|provision'
kubectl -n database get job | grep -i provision || true

# verify secrets and service
kubectl -n database get svc | grep -i minio
kubectl -n database get secret | grep -i minio
kubectl -n database get secret minio-auth -o go-template='{{range $k,$v := .data}}{{printf "%s\n" $k}}{{end}}'
kubectl -n database get secret minio-auth -o jsonpath='{.data.rootUser}' | base64 -d
```

Next verify buckets with `minio-client`, Start a temporary client pod and inspect the object-storage endpoint.

```sh
NS=database
SVC=minio
ROOT_SECRET=minio-auth
ROOT_USER="$(kubectl -n "$NS" get secret "$ROOT_SECRET" -o jsonpath='{.data.rootUser}' | base64 -d)"
ROOT_PASS="$(kubectl -n "$NS" get secret "$ROOT_SECRET" -o jsonpath='{.data.rootPassword}' | base64 -d)"

kubectl -n "$NS" run mc --rm -it --restart=Never \
  --image=bitnami/minio-client:2025.7.21-debian-12-r2 \
  --env="SVC=$SVC" \
  --env="ROOT_USER=$ROOT_USER" \
  --env="ROOT_PASS=$ROOT_PASS" \
  --command -- /bin/sh
```

Inside the shell, run:

```sh
set -e
mc alias set local "http://$SVC:9000" "$ROOT_USER" "$ROOT_PASS"
mc ls local
```

If the provisioning job completed successfully, the configured bucket should be visible in the output.
