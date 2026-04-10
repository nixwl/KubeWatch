# MySQL Deployment

It uses the Bitnami MySQL Helm chart and assumes a replicated deployment with one primary instance and one secondary replica. If you only want a single MySQL instance, set `architecture: standalone` and remove the `secondary` section from the values file.

## Prerequisites

- A Kubernetes namespace named `database`
- A writable storage class such as `nfs-client-storageclass`
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine

## Add The Helm Chart and Export Default Values

```sh
# add helm chart
helm repo list
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo mysql

# export values
helm show values bitnami/mysql > mysql-values.yaml
helm show readme bitnami/mysql > mysql-README.md
```

Use [mysql-values.yaml](../../configs/pipelines/workload/mysql-values.yaml) as the working configuration file.

## Create The Authentication Secret

Create the secret first, then reference it from the chart values.

```sh
kubectl -n database create secret generic mysql-auth \
  --from-literal=mysql-root-password='<password>' \
  --from-literal=mysql-password='<password>' \
  --from-literal=mysql-replication-password='<password>'
```

## Update The Values File

Require image replacement, persistent volumes, worker-node scheduling, internal networking, resource limits, and replication.

Since Bitnami charts have removed MySQL, the default images need to be replaced with bitnamilegacy.

```yaml
image:
  registry: docker.io
  repository: bitnamilegacy/mysql
  tag: 9.4.0-debian-12-r1
  digest: ""

volumePermissions:
  image:
    registry: docker.io
    repository: bitnamilegacy/os-shell
    tag: 12-debian-12-r50
    digest: ""
    pullPolicy: IfNotPresent
```

Reference the previously created secret(mysql-auth).

```yaml
auth:
  rootPassword: ""
  createDatabase: false
  database: ""
  username: ""
  password: ""
  replicationUser: replicator
  replicationPassword: ""
  existingSecret: mysql-auth
  usePasswordFiles: true
  customPasswordFiles: {}
  authenticationPolicy: ""
```

The source material eventually configures one primary plus one secondary replica, both with retained PVCs.

```yaml
primary:
  persistence:
    enabled: true
    storageClass: "nfs-client-storageclass"
    accessModes:
      - ReadWriteOnce
    size: 3Gi
    selector: {}
  persistentVolumeClaimRetentionPolicy:
    enabled: true
    whenScaled: Retain
    whenDeleted: Retain

secondary:
  replicaCount: 1
  persistence:
    enabled: true
    storageClass: "nfs-client-storageclass"
    accessModes:
      - ReadWriteOnce
    size: 3Gi
    selector: {}
  persistentVolumeClaimRetentionPolicy:
    enabled: true
    whenScaled: Retain
    whenDeleted: Retain
```

We require MySQL pods to run on worker nodes and to stay cluster-internal.

```yaml
primary:
  nodeSelector:
    node-role: worker
  podAntiAffinityPreset: hard
  service:
    type: ClusterIP
    ports:
      mysql: 3306
      mysqlx: 33060

secondary:
  nodeSelector:
    node-role: worker
  podAntiAffinityPreset: soft
  service:
    type: ClusterIP
    ports:
      mysql: 3306
      mysqlx: 33060
```

Disable the preset and declare explicit requests and limits.

```yaml
primary:
  resourcesPreset: "none"
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi

secondary:
  resourcesPreset: "none"
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

We set the default character set and collation.

```yaml
primary:
  configuration: |-
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    default-character-set=utf8mb4
```

## Install / Upgrade MySQL

Use either `install` for the first deployment or `upgrade --install` for an idempotent workflow.

```sh
helm install mysql8 bitnami/mysql -n database --create-namespace -f mysql-values.yaml
helm upgrade mysql8 bitnami/mysql -n database --create-namespace -f mysql-values.yaml
```

A safer day-2 command is:

```sh
helm upgrade --install mysql8 bitnami/mysql -n database --create-namespace -f mysql-values.yaml
```

## Verify The Deployment

Check pods, PVCs, and services after the release becomes ready.

```sh
kubectl -n database get pods -o wide
kubectl -n database get pvc
kubectl -n database get svc
helm -n database status mysql8
```

Expected in-cluster service endpoints:

```text
Primary:   mysql8-primary.database.svc.cluster.local:3306
Secondary: mysql8-secondary.database.svc.cluster.local:3306
```
