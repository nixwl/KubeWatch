# Garage Deployment

It uses the Garage project's Helm chart as a two-replica StatefulSet deployment on K3s. The document covers chart preparation, persistent storage, cluster layout assignment, and a basic S3 bucket plus access-key setup for an application.

## Prerequisites

- A Kubernetes namespace named `database`
- A writable storage class such as `nfs-client-storageclass`
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine
- Access to the Garage project repository in order to use its Helm chart

## Prepare The Helm Chart

Use the Helm chart that ships with the Garage repository instead of a public Helm repository.

```sh
git clone https://git.deuxfleurs.fr/Deuxfleurs/garage
cd garage/scripts/helm
ls
cd ..
mv helm/ /data/nfs-conf/garage/package/
cd /data/nfs-conf/garage/package
rm -rf garage
```

Then export the default values and create a working copy for local changes.

```sh
helm show values ./helm/garage > garage-values.yaml
```

> [garage-values.yaml](../../configs/pipelines/workload/garage-values.yaml)

```sh
helm upgrade --install garage /data/nfs-conf/garage/package/helm/garage \
  --namespace database \
  --create-namespace \
  -f garage-values.yaml
```

## Configure The Values File

We use two Garage nodes, so the logical replication factor is also set to 2.

```yaml
garage:
  replicationFactor: "2"
```

Garage stores metadata and object data separately. Both volumes need persistent storage.

```yaml
persistence:
  enabled: true
  meta:
    storageClass: "nfs-client-storageclass"
    size: 512Mi
    hostPath: /var/lib/garage/meta
  data:
    storageClass: "nfs-client-storageclass"
    size: 3Gi
    hostPath: /var/lib/garage/data
```

The deployment runs as a StatefulSet with two replicas so each Garage pod keeps stable storage and identity.

```yaml
deployment:
  kind: StatefulSet
  replicaCount: 2
  podManagementPolicy: OrderedReady
  image:
    repository: dxflrs/amd64_garage
    tag: ""
    pullPolicy: IfNotPresent
  initImage:
    repository: busybox
    tag: stable
    pullPolicy: IfNotPresent
  imagePullSecrets: []
```

We place the pods on worker nodes and use small explicit resource requests and limits.

```yaml
nodeSelector:
  node-role: worker

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi
```

## Configure The Garage Layout

After the pods are running, inspect the initial layout state.

```sh
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe layout show
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe status
```

We assign each node to a zone and set its usable capacity. The `--capacity` value is Garage's internal declared capacity and can be slightly lower than the actual PVC size.

```sh
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe layout assign \
  -z z1 \
  --capacity 5GiB \
  <layout-1>

kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe layout assign \
  -z z2 \
  --capacity 5GiB \
  <layout-2>

kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe layout show
```

Apply the layout once the assignments are correct.

```sh
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe layout apply --version 1
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe status
```

## Create A Bucket And Access Key

The source notes use `openproject` as the example application bucket.

First confirm the cluster is healthy and list the Garage pods.

```sh
kubectl -n database get pods
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe status
```

Create the bucket and verify it exists.

```sh
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe bucket create openproject
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe bucket list
```

Create an access key for the application and inspect the result.

```sh
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe key create openproject-key
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe key list
```

Grant the key read, write, and owner access to the bucket.

```sh
kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe bucket allow \
  --read --write --owner \
  openproject \
  --key openproject-key

kubectl -n database exec -it garage-0 -c garage -- /proc/1/exe bucket info openproject
```

Create a Kubernetes secret in the target application namespace so the application can use the Garage S3 endpoint.

```sh
kubectl create ns openproject
kubectl -n openproject create secret generic garage-openproject-auth \
  --from-literal=accessKeyId='openproject-key' \
  --from-literal=secretAccessKey='<generated-secret-access-key>'
```

## Verify Service Endpoints

Check the Garage services in the `database` namespace.

```sh
kubectl -n database get svc | grep -i garage
```

The source notes identify these in-cluster service endpoints:

```text
S3:  garage.database.svc.cluster.local:3900
Web: garage.database.svc.cluster.local:3902
```
