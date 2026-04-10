# Gitea Deployment

It uses the official Gitea Helm chart and follows the source notes as a multi-replica deployment on K3s. The installation uses an external MySQL database, shared persistent storage, Traefik ingress with HTTPS, and an optional Redis Sentinel integration to replace the default LevelDB-backed queue and session components.

Gitea is a lightweight, self-hosted Git service that provides the following features:

- Repository Hosting: Git repository management, branches/tags, access control, and web-based code browsing.
- Collaborative Development: Pull Requests, code reviews, comments, and diff viewing.
- Issue Tracking: Issues, milestones, and labels.
- CI/CD Integration: Supports integration with external CI tools (such as Jenkins, Drone, GitHub Actions runner, etc.) and provides Webhook support.
- Project Management Basics: Wikis, releases, attachments, and Kanban boards (depending on the version and configuration).
- Users and Permissions: Organizations/teams, fine-grained permissions, and support for LDAP/OAuth authentication (depending on the configuration).

## Prerequisites

- A Kubernetes namespace named `gitea`
- A writable storage class such as `nfs-client-storageclass`
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine
- An existing MySQL service for Gitea metadata storage
- An existing Redis Sentinel deployment if you want multi-replica queue, cache, and session support

## Prepare The Database

The source notes create the `gitea` database and user in the existing MySQL deployment before installing the Helm chart.

```sh
kubectl get pods -n database
kubectl -n database exec -it mysql8-primary-0 -- sh
mysql -u root -p
```

Inside MySQL:

```sql
CREATE DATABASE gitea CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'gitea'@'%' IDENTIFIED BY '<gitea-db-password>';
GRANT ALL PRIVILEGES ON gitea.* TO 'gitea'@'%';
FLUSH PRIVILEGES;
```

## Add The Helm Repository

```sh
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update
helm search repo gitea
```

Use [gitea-values.yaml](../../configs/pipelines/workload/gitea-values.yaml) as the working configuration file.

```sh
helm show values gitea-charts/gitea > gitea-values.yaml
```

Then install / upgrade the release.

```sh
helm upgrade --install gitea gitea-charts/gitea \
  -n gitea \
  -f gitea-values.yaml \
  --create-namespace
```

## Configure The Values File

We use external database and cache services, so the built-in chart subcomponents are disabled.

```yaml
valkey-cluster:
  enabled: false

postgresql-ha:
  enabled: false
```

We place Gitea on worker nodes and use small explicit resource requests and limits.

```yaml
nodeSelector:
  node-role: worker

resources:
  limits:
    cpu: 1
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 64Mi
```

Keep the Gitea HTTP service internal and expose the application through Traefik with HTTPS enabled.

```yaml
service:
  http:
    type: ClusterIP
    port: 3000
    clusterIP: None
```

```yaml
ingress:
  enabled: true
  className: "traefik"
  pathType: Prefix
  annotations:
    cert-manager.io/cluster-issuer: producer-ca-issuer
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
  hosts:
    - host: gitea.example.com
      paths:
        - path: /
  tls:
    - secretName: gitea-general-tls
      hosts:
        - gitea.example.com
```

We run two Gitea replicas, so the shared volume must support `ReadWriteMany`.

```yaml
replicaCount: 2

persistence:
  enabled: true
  create: true
  mount: true
  claimName: gitea-storage
  size: 1Gi
  accessModes:
    - ReadWriteMany
  storageClass: nfs-client-storageclass
  annotations:
    helm.sh/resource-policy: keep
```

Create the administrator secret first, then reference it from the values file.

```sh
kubectl -n gitea create secret generic gitea-admin-secret \
  --from-literal=username="admin" \
  --from-literal=password="<admin-password>" \
  --from-literal=email="admin@example.com"
```

```yaml
gitea:
  admin:
    existingSecret: gitea-admin-secret
    passwordMode: keepUpdated
  config:
    server:
      DOMAIN: gitea.example.com
      ROOT_URL: "https://gitea.example.com/"
      PROTOCOL: https
      HTTP_PORT: 3000
      START_SSH_SERVER: false
      SSH_PORT: 22
      SSH_LISTEN_PORT: 2222
      PUBLIC_URL_DETECTION: auto
    session:
      PROVIDER: db
    service:
      DISABLE_REGISTRATION: false
      REQUIRE_SIGNIN_VIEW: true
```

Create a secret for the external MySQL connection and load it into the deployment environment.

```sh
kubectl -n gitea create secret generic gitea-db-secret \
  --from-literal=HOST='mysql8-primary.database.svc.cluster.local:3306' \
  --from-literal=NAME='gitea' \
  --from-literal=USER='gitea' \
  --from-literal=PASSWD='<gitea-db-password>'
```

```yaml
deployment:
  env:
    - name: GITEA__database__DB_TYPE
      value: mysql
    - name: GITEA__database__HOST
      valueFrom:
        secretKeyRef:
          name: gitea-db-secret
          key: HOST
    - name: GITEA__database__NAME
      valueFrom:
        secretKeyRef:
          name: gitea-db-secret
          key: NAME
    - name: GITEA__database__USER
      valueFrom:
        secretKeyRef:
          name: gitea-db-secret
          key: USER
    - name: GITEA__database__PASSWD
      valueFrom:
        secretKeyRef:
          name: gitea-db-secret
          key: PASSWD
    - name: GITEA__database__SSL_MODE
      value: disable
    - name: GITEA__database__CHARSET
      value: utf8mb4
```

## Add HTTP-To-HTTPS Redirection

The chart-managed ingress is configured for `websecure`, so the source notes also add a Traefik middleware and a separate HTTP ingress that redirects plain HTTP traffic to HTTPS.

> - [gitea-middleware.yaml](../../configs/pipelines/workload/gitea-middleware.yaml)
> - [gitea-redirect.yaml](../../configs/pipelines/workload/gitea-redirect.yaml)

```yaml
# gitea-middleware.yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: redirect-to-https
  namespace: gitea
spec:
  redirectScheme:
    scheme: https
    permanent: true
```

```yaml
# gitea-redirect.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitea-http-redirect
  namespace: gitea
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
    traefik.ingress.kubernetes.io/router.middlewares: gitea-redirect-to-https@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
    - host: gitea.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gitea-http
                port:
                  number: 3000
```

```sh
# Apply the redirect resources
kubectl apply -f gitea-middleware.yaml
kubectl apply -f gitea-redirect.yaml

# Verify the redirect behavior
curl -I http://gitea.example.com/ | egrep -i "HTTP/|location:"
curl -Ik https://gitea.example.com/ | head
```

## Verify The Deployment

```sh
kubectl get pods -n gitea
kubectl describe pods -n gitea
kubectl logs -n gitea deploy/gitea -c configure-gitea
kubectl logs -n gitea deploy/gitea -c init-directories
kubectl logs -n gitea deploy/gitea -c init-app-ini
kubectl rollout restart deployment/gitea -n gitea
```

## Optional: Move Sessions, Cache, Queue, And Global Lock To Redis Sentinel

We found a real multi-replica issue: the default LevelDB-based queue backend is not suitable for multi-pod Gitea. The recommended follow-up is to move session, cache, queue, and global lock state to Redis Sentinel.

First confirm the Redis Sentinel endpoints and master name.

```sh
kubectl -n database run -it --rm redis-cli \
  --image=redis:7-alpine --restart=Never -- \
  sh -lc "redis-cli -a '<redis-password>' -h redis-ha -p 26379 sentinel get-master-addr-by-name ha-master"
```

The source notes use these Sentinel endpoints:

```text
redis-ha-node-0.redis-ha-headless.database.svc.cluster.local:26379
redis-ha-node-1.redis-ha-headless.database.svc.cluster.local:26379
redis-ha-node-2.redis-ha-headless.database.svc.cluster.local:26379
```

Create a secret that stores the final Redis Sentinel connection strings.

```sh
kubectl -n gitea create secret generic gitea-redis-conn \
  --from-literal=session='redis+sentinel://gitea:<redis-password>@redis-ha-node-0.redis-ha-headless.database.svc.cluster.local:26379,redis-ha-node-1.redis-ha-headless.database.svc.cluster.local:26379,redis-ha-node-2.redis-ha-headless.database.svc.cluster.local:26379/0?master_name=ha-master&sentinel_password=<redis-password>&pool_size=100&idle_timeout=120s' \
  --from-literal=cache='redis+sentinel://gitea:<redis-password>@redis-ha-node-0.redis-ha-headless.database.svc.cluster.local:26379,redis-ha-node-1.redis-ha-headless.database.svc.cluster.local:26379,redis-ha-node-2.redis-ha-headless.database.svc.cluster.local:26379/1?master_name=ha-master&sentinel_password=<redis-password>' \
  --from-literal=queue='redis+sentinel://gitea:<redis-password>@redis-ha-node-0.redis-ha-headless.database.svc.cluster.local:26379,redis-ha-node-1.redis-ha-headless.database.svc.cluster.local:26379,redis-ha-node-2.redis-ha-headless.database.svc.cluster.local:26379/2?master_name=ha-master&sentinel_password=<redis-password>' \
  --from-literal=lock='redis+sentinel://:<redis-password>@redis-ha-node-0.redis-ha-headless.database.svc.cluster.local:26379,redis-ha-node-1.redis-ha-headless.database.svc.cluster.local:26379,redis-ha-node-2.redis-ha-headless.database.svc.cluster.local:26379/5?master_name=ha-master&sentinel_password=<redis-password>'
```

Then add the Redis-backed runtime settings to the deployment:

```yaml
#! gitea-values.yaml
deployment:
  env:
    - name: GITEA__session__PROVIDER
      value: redis
    - name: GITEA__session__PROVIDER_CONFIG
      valueFrom:
        secretKeyRef:
          name: gitea-redis-conn
          key: session
    - name: GITEA__cache__ADAPTER
      value: redis
    - name: GITEA__cache__HOST
      valueFrom:
        secretKeyRef:
          name: gitea-redis-conn
          key: cache
    - name: GITEA__queue__TYPE
      value: redis
    - name: GITEA__queue__CONN_STR
      valueFrom:
        secretKeyRef:
          name: gitea-redis-conn
          key: queue
    - name: GITEA__global_lock__SERVICE_TYPE
      value: redis
    - name: GITEA__global_lock__SERVICE_CONN_STR
      valueFrom:
        secretKeyRef:
          name: gitea-redis-conn
          key: lock
```

Re-apply the release and verify the runtime configuration:

```sh
helm upgrade --install gitea gitea-charts/gitea \
  -n gitea \
  -f gitea-values.yaml \
  --create-namespace

kubectl -n gitea rollout restart deploy/gitea
kubectl -n gitea rollout status deploy/gitea
kubectl -n gitea logs deploy/gitea --tail=200 | egrep -i "sentinel|noauth|redis|queue|leveldb"
kubectl -n gitea exec deploy/gitea -c gitea -- sh -c 'env | grep -E "^GITEA__queue__(TYPE|CONN_STR)="'
```
