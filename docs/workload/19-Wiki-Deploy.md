# Wiki.js Deployment

Wiki.js is a modern, open-source knowledge base and Wiki system designed to make "writing documentation as easy as writing Markdown." It is ideal for building internal team documentation sites, operations manuals, project knowledge bases, and SOPs/Runbooks. It supports self-hosted deployments (Docker, Kubernetes, Linux, etc.) and offers modular extensibility.

- Markdown-based writing: Provides a user-friendly editing experience that feels more like a modern "document editor" than a traditional Wiki.
- Built-in User/Group Access Control: Enables permission isolation across different namespaces and paths.
- Guest Access Control: By clearing the permissions for the "Guests" group, you can easily enforce a "Login Required" policy for the entire site.
- Comprehensive Authentication Options:
  - Local accounts
  - LDAP / Active Directory
  - OAuth (e.g., GitHub, Google)
  - SAML 2.0 (Commonly used for Enterprise SSO)
- Modular & Pluggable Extensions:
  - Authentication: Identity providers
  - Comments: User discussion integrations
  - Editors: Multiple editing modes
  - Rendering: Specialized content rendering
  - Search Engines: Pluggable search backends
  - Storage: Backup and sync to external storage targets

## Prerequisites

- A Kubernetes namespace named `wiki`
- A working PostgreSQL deployment in the `database` namespace
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine
- A DNS name such as `wiki.example.com`
- A certificate issuer such as `producer-ca-issuer`

## Prepare The PostgreSQL Database

The Wiki values file expects an external PostgreSQL database named `wiki`, a user named `wiki`, and a Kubernetes secret named [postgresql-wiki-secret](../../configs/pipelines/workload/wiki-postgre-secret.yaml).

Start a temporary PostgreSQL client pod and connect to the primary service:

```sh
kubectl -n database run psql --rm -it --restart=Never \
  --image=alpine/psql:18.1 \
  --env="PGPASSWORD=<postgres-password>" \
  --command -- psql -h pg-postgresql-primary -U postgres -d postgres
```

Inside PostgreSQL, create the Wiki.js user and database:

```pgsql
CREATE ROLE wiki LOGIN PASSWORD 'wiki123!' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE DATABASE wiki OWNER wiki;
REVOKE ALL ON DATABASE wiki FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE wiki TO wiki;
\c wiki
CREATE SCHEMA IF NOT EXISTS wiki AUTHORIZATION wiki;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE USAGE ON SCHEMA public FROM PUBLIC;
ALTER ROLE wiki IN DATABASE wiki SET search_path = wiki,public;
```

Verify basic connectivity:

```sh
PG_HOST="pg-postgresql-primary.database.svc.cluster.local"
kubectl -n wiki run psql-test --rm -it --restart=Never --image=postgres:17-alpine -- \
  sh -lc "PGPASSWORD=wiki123! psql -h '${PG_HOST}' -U 'wiki' -d 'wiki' -c 'select current_user, current_database();'"
```

## Add The Helm Repository

```sh
helm repo add requarks https://charts.js.wiki
helm repo update
helm search repo
# expot values
helm show values requarks/wiki --version 2.2.24 > wiki-values.yaml

```

## Configure Values

set the replica count and enable High Availability (HA).

```yaml
replicaCount: 2
extraEnvVars:
  - name: HA_ACTIVE
    value: "true"
```

set ingress

```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    cert-manager.io/cluster-issuer: producer-ca-issuer
    traefik.ingress.kubernetes.io/router.entrypoints: websecure

  hosts:
    - host: wiki.example.com
      paths:
        - path: "/"
          pathType: Prefix
  tls:
    - secretName: wiki-general-tls
      hosts:
        - wiki.example.com
```

set postgre

```yaml
postgresql:
  enabled: false
  postgresqlHost: "pg-postgresql-primary.database.svc.cluster.local"
  postgresqlPort: 5432

  fullnameOverride: ""
  postgresqlUser: wiki
  postgresqlDatabase: wiki
  existingSecret: "postgresql-wiki-secret"
  existingSecretKey: "DB_PASS"
  ssl: false

  replication:
    enabled: false
  persistence:
    enabled: false
    accessMode: ReadWriteOnce
    size: 8Gi
```

set scheduling and resource configurations.

```yaml
nodeSelector:
  node-role: worker
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.kubernetes.io/instance: wiki
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: "1"
    memory: 512Mi
```

After modification, save it as: [wiki-values-2.yaml](../../configs/pipelines/workload/wiki-values-2.yaml)

## Install Wiki

Start with a single replica to initialize Wiki.js, then scale to multiple replicas and prepare the startup configuration.

```sh
# init
helm upgrade --install wiki requarks/wiki -n wiki --create-namespace --version 2.2.24 -f custom-values.yaml

# check status
kubectl -n wiki get deploy,po,svc,ing -o wide
kubectl -n wiki logs -l app.kubernetes.io/instance=wiki --tail=200

# to HA
helm upgrade --install wiki requarks/wiki -n wiki --create-namespace --version 2.2.24 -f custom-values.yaml -f custom-values-2.yaml
```

Additionally, a Pod Disruption Budget (PDB) is required to ensure that Wiki containers are automatically distributed across different nodes.

> [wiki-pdb.yaml](../../configs/pipelines/workload/wiki-pdb.yaml)

```sh
kubectl apply -f wiki-pdb.yaml
# check
kubectl -n wiki get deploy,po -o wide
kubectl -n wiki describe deploy wikijs | sed -n '1,120p'
kubectl -n wiki get pod -l app.kubernetes.io/instance=wiki -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount
```
