# PostgreSQL Deployment

It uses the Bitnami PostgreSQL Helm chart and follows the source notes as a primary plus read-replica deployment with persistent volumes. The chart configuration keeps the built-in `postgres` administrator account, enables streaming replication, and leaves business database creation to a post-install SQL step.

## Prerequisites

- A Kubernetes namespace named `database`
- A writable storage class such as `nfs-client-storageclass`
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine

## Add The Helm Chart and Export Values

We pin the chart version to `18.2.3` before editing the values file. Use `postgresql-values.yaml` as the working configuration file.

```sh
# add charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo postgresql
# export
helm show values bitnami/postgresql --version 18.2.3 > postgresql-values.yaml
```

> [postgresql-values.yaml](../../configs/pipelines/workload/postgresql-values.yaml)

```sh
helm upgrade --install pg bitnami/postgresql \
  --version 18.2.3 \
  -n database \
  -f postgresql-values.yaml
```

You can also create the namespace first and then apply the secret separately.

## Create Authentication Secret

Define a single [secret](../../configs/pipelines/workload/postgresql-secret.yaml) that stores the administrator, replication, and application-user passwords required by the chart.

## Configure The Values File

### 1. Authentication

Do not hard-code passwords in `postgresql-values.yaml`. Reference the previously created secret and keep application database creation disabled at install time.

```yaml
auth:
  enablePostgresUser: true
  postgresPassword: ""
  username: ""
  password: ""
  database: ""
  replicationUsername: repl
  replicationPassword: ""
  existingSecret: pg-cluster-auth
  secretKeys:
    adminPasswordKey: postgres-password
    userPasswordKey: password
    replicationPasswordKey: replication-password
  usePasswordFiles: true
```

### 3. Primary Node

The primary instance keeps persistent storage, runs on worker nodes, and applies a small set of PostgreSQL tuning parameters.

```yaml
volumePermissions:
  enabled: false
# primary database setting
primary:
  name: primary
  extendedConfiguration: |
    max_connections = 50
    shared_buffers = 128MB
    work_mem = 4MB
    maintenance_work_mem = 64MB
  resourcesPreset: none
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 512Mi
  nodeSelector:
    node-role: worker
  persistence:
    enabled: true
    volumeName: data
    existingClaim: ""
    mountPath: /bitnami/postgresql
    subPath: ""
    storageClass: nfs-client-storageclass
    accessModes:
      - ReadWriteOnce
    size: 5Gi
    annotations: {}
    labels: {}
    selector: {}
    dataSource: {}
  persistentVolumeClaimRetentionPolicy:
    enabled: true
    whenScaled: Retain
    whenDeleted: Retain
```

### 4. Read Replica

The notes deploy one read replica with the same resource and persistence profile as the primary node.

```yaml
readReplicas:
  name: read
  replicaCount: 1
  extendedConfiguration: |
    max_connections = 50
    shared_buffers = 128MB
    work_mem = 4MB
    maintenance_work_mem = 64MB
  resourcesPreset: none
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 512Mi
  nodeSelector:
    node-role: worker
  persistence:
    enabled: true
    existingClaim: ""
    mountPath: /bitnami/postgresql
    subPath: ""
    storageClass: nfs-client-storageclass
    accessModes:
      - ReadWriteOnce
    size: 5Gi
    annotations: {}
    labels: {}
    selector: {}
    dataSource: {}
  persistentVolumeClaimRetentionPolicy:
    enabled: true
    whenScaled: Retain
    whenDeleted: Retain
```

### 5. Shared Libraries

Disable preload libraries and enable an in-memory shared-memory volume.

```yaml
# disable audit
postgresqlSharedPreloadLibraries: ""

# enable shmVolume
shmVolume:
  enabled: true
  sizeLimit: "128Mi"
```

## Verify The Deployment

Check the Helm release, pods, PVCs, services, and endpoints after the install completes.

```sh
helm -n database status pg
helm -n database get values pg
helm -n database get manifest pg | head
kubectl -n database get pods -o wide
kubectl -n database get pvc -o wide
kubectl -n database describe pvc
kubectl -n database get svc
kubectl -n database get endpoints
```

Then confirm that streaming replication is active on the primary node.

```sh
kubectl -n database exec -it pg-postgresql-primary-0 -- \
  psql -U postgres -x -c "select client_addr,state,sync_state,write_lag,flush_lag,replay_lag from pg_stat_replication;"
```

## Option: Create A Database And Application User

Start a temporary PostgreSQL client pod and connect to the primary service with the `postgres` administrator account.

```sh
kubectl -n database get svc | egrep -i 'pg|postgres'
kubectl -n database run psql --rm -it --restart=Never \
  --image=alpine/psql:18.1 \
  --env="PGPASSWORD=<postgres-password>" \
  --command -- psql -h pg-postgresql-primary -U postgres -d postgres
```

Inside the SQL shell, first inspect the server state.

```pgsql
SELECT version();
\conninfo
\l
\du
```

Then create the application role and database. W use `wiki` as the example business database.

```pgsql
-- 1. create user
CREATE ROLE wiki LOGIN PASSWORD 'wiki123!' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
-- 2. create database
CREATE DATABASE wiki OWNER wiki;
-- 3. revoke default public schema permissions.
REVOKE ALL ON DATABASE wiki FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE wiki TO wiki;
-- 4. grant schema permissions after logging into the database.
\c wiki
CREATE SCHEMA IF NOT EXISTS wiki AUTHORIZATION wiki;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE USAGE ON SCHEMA public FROM PUBLIC;
ALTER ROLE wiki IN DATABASE wiki SET search_path = wiki,public;
```

Useful follow-up checks:

```pgsql
--- get all databases and check current user, database and connection info
SELECT datname FROM pg_database ORDER BY 1;
SELECT current_user;
SELECT current_database();
\conninfo
\du
```
