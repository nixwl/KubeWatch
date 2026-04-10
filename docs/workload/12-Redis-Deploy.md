# Redis Deployment

It uses the Bitnami Redis Helm chart and assumes a high-availability deployment with replication and Sentinel enabled. If you only need a single Redis instance, switch the chart architecture accordingly and disable Sentinel.

## Prerequisites

- A Kubernetes namespace named `database`
- A writable storage class such as `nfs-client-storageclass`
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine

## Update Chart and Export The Default Chart Values

```sh
helm repo update
helm search repo redis
```

The source notes use the `bitnami/redis` chart because it supports both standalone mode and replication plus Sentinel failover.

```sh
helm show values bitnami/redis > redis-values.yaml
```

Use [`redis-values.yaml`](../../configs/pipelines/workload/redis-values.yaml) as the working configuration file.

## Create The Authentication Secret

Create the base Redis password secret before installing the chart.

```sh
kubectl -n database create secret generic redis-auth --from-literal=redis-password='<redis-password>'
```

## Configure Values

### 1. Configure Replication And Basic Authentication

The base deployment in the source notes uses replication plus RBAC.

```yaml
architecture: replication

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

rbac:
  create: true
```

### 2. Configure Master, Replica, And Sentinel

To deploy Redis with High Availability (HA), configure the Master and the Sentinel separately.

#### 2.1 Master Node

```yaml
master:
  count: 1
  resourcesPreset: "none"
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 256Mi
  nodeSelector:
    node-role: worker
  persistence:
    enabled: true
    storageClass: "nfs-client-storageclass"
    accessModes:
      - ReadWriteOnce
    size: 1Gi
  persistentVolumeClaimRetentionPolicy:
    enabled: true
    whenScaled: Retain
    whenDeleted: Retain
```

#### 2.2 Replica Nodes

Set the number of replicas to 2; this will result in a total of 3 Redis Pods for High Availability.

```yaml
replica:
  kind: StatefulSet
  replicaCount: 2
  resourcesPreset: "none"
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 256Mi
  nodeSelector:
    node-role: worker
  persistence:
    enabled: true
    storageClass: "nfs-client-storageclass"
    accessModes:
      - ReadWriteOnce
    size: 1Gi
  persistentVolumeClaimRetentionPolicy:
    enabled: true
    whenScaled: Retain
    whenDeleted: Retain
```

#### 2.3 Sentinel

When Sentinel is enabled, each Redis pod also runs a Sentinel container. The chart then exposes a unified service model suitable for automatic failover.

```yaml
sentinel:
  enabled: true
  masterSet: ha-master
```

### 3. Optional ACL Multi-User Configuration

We also enable ACL-based multi-user access. First, We should confirm the current ACL state.

```sh
kubectl -n database exec -it redis-ha-node-0 -- redis-cli -a <redis-password> ACL USERS
helm -n database get values redis-ha -o yaml | grep -nE 'auth:|acl:'
```

Next, enable ACL-based user access control.

```yaml
auth:
  acl:
    enabled: true
    sentinel: true
```

We use `gitea` as an example ACL user.

```sh
kubectl -n database create secret generic redis-acl-users \
  --from-literal=default='<gitea-acl-password>' \
  --from-literal=gitea='<gitea-acl-password>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Finally, add the ACL users to `redis-values.yaml` and upgrade redis deployments.

```yaml
auth:
  enabled: true
  acl:
    enabled: true
    sentinel: true
    userSecret: redis-acl-users
    users:
      - username: gitea
        enabled: "on"
        commands: "+@all -ACL -CONFIG -SHUTDOWN -FLUSHALL -FLUSHDB -DEBUG -MODULE"
        keys: "~*"
        channels: "&*"
```

```sh
helm upgrade --install redis-ha bitnami/redis -n database -f redis-values.yaml
# check, If the login is successful, Redis should respond with `PONG`.
kubectl -n database exec -it redis-ha-node-0 -c redis -- redis-cli -a 12345678 ACL USERS

# Direct Redis test
kubectl -n database exec -it redis-ha-node-0 -c redis -- \
  redis-cli --user gitea -a 'GITEA_REDIS_STRONG_PASS' PING

# Sentinel test
kubectl -n database exec -it redis-ha-node-0 -c sentinel -- \
  redis-cli -p 26379 --user gitea -a 'GITEA_REDIS_STRONG_PASS' \
  SENTINEL get-master-addr-by-name ha-master
```
