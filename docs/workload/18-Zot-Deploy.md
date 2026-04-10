# Zot Deployment

It uses the Zot Helm chart to deploy a lightweight OCI registry on K3s. The source notes run Zot in a two-replica setup with Traefik ingress, store image data in MinIO through the S3 storage driver, and use Redis Sentinel for both cache and session state.

## Prerequisites

- A Kubernetes namespace named `zot`
- A working MinIO deployment in the `database` namespace
- A working Redis Sentinel deployment in the `database` namespace
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine
- A DNS name such as `zot.example.com`

## Add The Helm Repository and Export Values

```sh
helm repo add zot http://zotregistry.dev/helm-charts
helm repo update
helm search repo zot/zot -l | head
```

Export the default values from the chart version used by the source notes.

```sh
helm show values zot/zot --version 0.1.95 > zot-values.yaml
```

Use [zot-values.yaml](../../configs/pipelines/workload/zot-values.yaml) as the working configuration file.

## Prepare MinIO And Redis

First confirm the in-cluster MinIO and Redis addresses.

```sh
kubectl -n database get svc | egrep -i 'minio|s3'
kubectl -n database describe svc minio | egrep -i 'Port:|TargetPort:|Endpoints:'
kubectl -n database get svc | egrep -i 'redis|ha|haproxy'
kubectl -n database describe svc redis-ha | egrep -i 'Port:|TargetPort:|Endpoints:'
```

Expected endpoints:

```text
MinIO: http://minio.database.svc.cluster.local:9000
Redis: http://redis-ha.database.svc.cluster.local:6379
```

We use a dedicated bucket named `zot` and a dedicated MinIO user also named `zot`.

```sh
kubectl -n database run mc-tmp --rm -i --tty --restart=Never \
  --image=bitnamilegacy/minio-client:2025.7.21-debian-12-r2 \
  --env MINIO_URL="http://minio.database.svc.cluster.local:9000" \
  --env MINIO_ROOT_USER="admin" \
  --env MINIO_ROOT_PASSWORD="<minio-root-password>" \
  --command -- /bin/sh
```

Inside the MinIO client shell:

```sh
MC="/opt/bitnami/minio-client/bin/mc"
$MC alias set m http://minio.database.svc.cluster.local:9000 admin <minio-root-password>
$MC mb -p m/zot
$MC admin user add m zot <zot-minio-password>
$MC admin policy attach m readwrite --user zot
$MC ls m
```

Generate a service account for the `zot` MinIO user and store it as a [Kubernetes secret](../../configs/pipelines/workload/zot-minio_s3_secret.yaml) in the `zot` namespace.

```sh
# get minio access key and secret key
mc alias set myminio http://minio.database.svc.cluster.local:9000 admin <minio-root-password>
mc admin user svcacct add myminio zot
```

We also add a dedicated Redis ACL user named `zot` so Zot can use Redis Sentinel for cache and sessions.

```sh
# add zot acl secret to redis
kubectl -n database create secret generic redis-acl-users \
  --from-literal=default='<redis-default-password>' \
  --from-literal=gitea='<gitea-redis-password>' \
  --from-literal=zot='<zot-redis-password>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Ensure the [Redis chart values](../../configs/pipelines/workload/redis-values.yaml) include the `zot` ACL user:

```yaml
# in redis-values.yaml
auth:
  enabled: true
  acl:
    enabled: true
    sentinel: true
    userSecret: redis-acl-users
    users:
      - username: zot
        enabled: "on"
        commands: "+@all -ACL -CONFIG -SHUTDOWN -FLUSHALL -FLUSHDB -DEBUG -MODULE"
        keys: "~*"
        channels: "&*"
```

Then re-apply Redis and verify Sentinel access:

```sh
helm upgrade --install redis-ha bitnami/redis -n database -f redis-values.yaml
# check
kubectl -n database exec -it redis-ha-node-0 -c sentinel -- \
  redis-cli -p 26379 --user zot -a '<zot-redis-password>' \
  SENTINEL get-master-addr-by-name ha-master
```

## Configure Zot

The source notes run Zot in HA mode with two replicas and pin the container image tag.

```yaml
# ! zot-values.yaml
replicaCount: 2

image:
  repository: ghcr.io/project-zot/zot
  pullPolicy: IfNotPresent
  tag: "v2.1.13"
```

Keep the Zot service internal and expose it through Traefik with TLS and sticky sessions.

```yaml
# ! zot-values.yaml
service:
  type: ClusterIP
  port: 5000
  annotations: {}
  clusterIP: null

ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: producer-ca-issuer
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.entrypoints: "websecure"
    traefik.ingress.kubernetes.io/service.sticky.cookie: "true"
    traefik.ingress.kubernetes.io/service.sticky.cookie.name: "ZOT_STICKY"
  className: "traefik"
  pathtype: ImplementationSpecific
  hosts:
    - host: zot.example.com
      paths:
        - path: /
  tls:
    - secretName: zot-general-tls
      hosts:
        - zot.example.com
```

We enable `mountConfig` and inject a custom `config.json` that uses:

- MinIO S3 storage for image data
- Redis Sentinel for the remote cache
- Redis Sentinel for session storage
- `htpasswd` authentication mounted from a secret

```yaml
# ! zot-values.yaml
mountConfig: true

configFiles:
  config.json: |-
    {
      "storage": {
        "rootDirectory": "/tmp/zot",
        "dedupe": false,
        "remoteCache": true,
        "storageDriver": {
          "name": "s3",
          "rootdirectory": "/",
          "bucket": "zot",
          "region": "us-east-1",
          "regionendpoint": "http://minio.database.svc.cluster.local:9000",
          "secure": false,
          "skipverify": false,
          "forcepathstyle": true
        },
        "cacheDriver": {
          "name": "redis",
          "keyprefix": "zotcache",
          "addr": [
            "redis-ha-node-0.redis-ha-headless.database.svc.cluster.local:26379",
            "redis-ha-node-1.redis-ha-headless.database.svc.cluster.local:26379",
            "redis-ha-node-2.redis-ha-headless.database.svc.cluster.local:26379"
          ],
          "master_name": "ha-master",
          "username": "zot",
          "password": "<zot-redis-password>",
          "sentinel_username": "zot",
          "sentinel_password": "<zot-redis-password>",
          "db": 10
        }
      },
      "http": {
        "address": "0.0.0.0",
        "port": "5000",
        "auth": {
          "htpasswd": { "path": "/secret/htpasswd" },
          "sessionDriver": {
            "name": "redis",
            "keyprefix": "zotsession",
            "addr": [
              "redis-ha-node-0.redis-ha-headless.database.svc.cluster.local:26379",
              "redis-ha-node-1.redis-ha-headless.database.svc.cluster.local:26379",
              "redis-ha-node-2.redis-ha-headless.database.svc.cluster.local:26379"
            ],
            "master_name": "ha-master",
            "username": "zot",
            "password": "<zot-redis-password>",
            "sentinel_username": "zot",
            "sentinel_password": "<zot-redis-password>",
            "db": 11
          }
        }
      },
      "log": { "level": "info" }
    }
```

Mount the [htpasswd]() secret into the container and pass the MinIO service-account credentials as environment variables.

```yaml
externalSecrets:
  - secretName: "zot-htpasswd"
    mountPath: "/secret"

mountSecret: false

env:
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: minio-zot-s3-credentials
        key: MINIO_ACCESS_KEY
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: minio-zot-s3-credentials
        key: MINIO_SECRET_KEY
  - name: AWS_REGION
    value: "us-east-1"
  - name: AWS_EC2_METADATA_DISABLED
    value: "true"
```

Because the source notes use MinIO for persistent storage, chart-managed PVC storage is disabled.

```yaml
persistence: false

pvc:
  create: true
  name: null
  accessModes: ["ReadWriteMany"]
  storage: 5Gi
  storageClassName: nfs-client-storageclass
```

## Deploy Zot

Create the target namespace and generate an `htpasswd` file for the Zot users.

```sh
kubectl create ns zot
# generate htpasswd
PASS_ADMIN='admin'
PASS_USER='user'
docker run --rm httpd:2.4-alpine htpasswd -nbB admin "$PASS_ADMIN" > htpasswd
docker run --rm httpd:2.4-alpine htpasswd -nbB user "$PASS_USER" >> htpasswd
cat htpasswd
```

Then, create the Kubernetes secret:

```sh
kubectl -n zot create secret generic zot-htpasswd \
  --from-file=htpasswd=./htpasswd \
  --dry-run=client -o yaml > zot-htpasswd-secret.yaml
kubectl apply -f zot-htpasswd-secret.yaml
```

We also generate a Basic Auth probe header from the admin credentials, If your chart values use an `authHeader`, place the resulting value there.

```sh
printf 'admin:%s' "$PASS_ADMIN" | base64 | tr -d '\n'; echo
```

We should inject `node-role=worker` into the Zot workload by using a Helm [post-renderer script](../../scripts/pipelines/workload/zot-post-render.sh). Validate the rendered manifests first:

```sh
chmod +x ./zot-post-render.sh
# verify post render results
helm template zot zot/zot -n zot -f zot-values.yaml | ./post-render.sh > /tmp/zot.rendered.yaml
# upgrade
helm upgrade --install zot zot/zot \
  -n zot \
  --create-namespace \
  -f zot-values.yaml \
  --post-renderer ./zot-post-render.sh
```

## Verify The Deployment

Check the replica count:

```sh
kubectl -n zot get pods -o wide
```

Check the ingress and TLS secret:

```sh
kubectl -n zot get ingress
kubectl -n zot get secret | grep -E 'zot-general-tls|tls'
kubectl -n zot describe ingress zot | sed -n '1,200p'
```

Test in-cluster access:

```sh
kubectl -n zot run curl --rm -it --restart=Never --image=curlimages/curl -- \
  sh -lc 'curl -sS -u admin:'"$PASS_ADMIN"' http://zot:5000/v2/ && echo OK'
```

Test external access:

```sh
nslookup zot.example.com
curl -k -sS -o /dev/null -w "%{http_code}\n" https://zot.example.com/v2/
curl -k -u 'admin:admin' -sS -D- https://zot.example.com/v2/_catalog -o /dev/null
curl -k -u 'admin:admin' -sS https://zot.example.com/v2/_catalog
```

## Pull Mirror Images Into Zot With skopeo

Skopeo is an open-source command-line utility for performing various operations on container images and image registries. It is part of a suite of "daemonless" container tools (alongside Podman and Buildah) developed by Red Hat and the open-source community.

```sh
# install
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# add kubic repo(xUbuntu 20.04)
echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/ /' \
| sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.

# download gpgs
curl -fsSL 'https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/Release.key' \
| gpg --dearmor \
| sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg > /dev/

# instll
sudo apt update
sudo apt install -y skopeo
skopeo --version
```

First, you need to create an auth.json

```sh
# create file
touch /data/nfs-conf/zot/skopeo/auth.json
export AUTHFILE="/data/nfs-conf/zot/skopeo/auth.json"
# verify the login to Zot and write the access token to the specified file.
kubectl -n zot create secret generic skopeo-auth --from-file=auth.json="$AUTHFILE"
# cache zot accesstoken
skopeo login --authfile "$AUTHFILE" --tls-verify=false -u admin zot.example.com
# check
kubectl -n zot get secret skopeo-auth -o jsonpath='{.data.auth\.json}' | wc -c
```

Next, generate an access token in Docker Hub, and then perform a skopeo login to docker.io to cache the authentication information for the upstream repository.

```sh
export AUTHFILE="/data/nfs-conf/zot/skopeo/auth.json"
printf '%s\n' '<access_token>' | skopeo login \
  --authfile "$AUTHFILE" \
  -u <user> \
  --password-stdin \
  docker.io
```

Next, we can perform a bulk pull of images from the registry. Start by creating a list of the [images](../../configs/pipelines/workload/images.txt) to be pulled.

```sh
# createa images list configmap
kubectl -n zot create configmap skopeo-mirror-list --from-file=images.txt=./images.txt

# store the Zot credentials (username and password) for image synchronization in a Secret
kubectl -n zot create secret generic skopeo-mirror-credentials \
  --from-literal=DEST_USER=admin \
  --from-literal=DEST_PASS='admin'
```

Use a batch synchronization job for image syncing.

> [zot-skopeo-sync_job.yaml](../../configs/pipelines/workload/zot-skopeo-sync_job.yaml)

```sh
# pull
kubectl apply -f zot-skopeo-sync_job.yaml
# check status
curl -sS -u admin:admin -k 'https://zot.example.com/v2/_catalog?n=1000' | jq
```
