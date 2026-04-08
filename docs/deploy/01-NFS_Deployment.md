# NFS Deployment

After completing [Kubernetes_Deployment.md](./Kubernetes_Deployment.md), proceed with the NFS deployment.

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

K3s includes local storage support, but shared `ReadWriteMany` storage usually requires an external backend. In this lab, NFS is used as the shared storage layer, and `nfs-subdir-external-provisioner` is used to dynamically provision PersistentVolumes for workloads.

The source notes assume the following example environment:

- NFS server: `nfs1` (`192.168.52.12`)
- Client network: `192.168.52.0/24`
- Shared storage root: `/data/nfs-data`
- Dynamic provisioner path: `/data/nfs-data/monitor/provisioner`

## NFS Server Setup

Run the following steps on the NFS server.

### 1. Install NFS Packages

On Ubuntu, install `rpcbind` and `nfs-kernel-server`:

```sh
 apt update
 apt install -y rpcbind nfs-kernel-server
```

> Some distributions expose the server service as `nfs-server`. On Ubuntu Server, the package and service name are typically `nfs-kernel-server`.

### 2. Create Shared Directories

Create the shared directory structure used by the lab:

```sh
mkdir -p /data/nfs-data/monitor/provisioner
mkdir -p /data/nfs-data/producer/provisioner
mkdir -p /data/nfs-conf
```

### 3. Export the Directories

Edit `/etc/exports`:

```sh
vim /etc/exports
```

Example:

```text
/data/nfs-data/monitor/provisioner 192.168.52.0/24(rw,no_root_squash,no_subtree_check)
/data/nfs-data/producer/provisioner 192.168.52.0/24(rw,no_root_squash,no_subtree_check)
/data/nfs-conf 192.168.52.0/24(rw,no_root_squash,no_subtree_check)
```

Option summary:

- `rw`: allow clients to read and write
- `sync`: commit writes synchronously
- `no_root_squash`: preserve root privileges from the client
- `no_subtree_check`: disable subtree permission checks

Apply the exports:

```sh
exportfs -arv
# Check if the mount point is correct
showmount -e
```

### 4. Start and Enable Services

```sh
systemctl start rpcbind && systemctl start nfs-server
systemctl status rpcbind && systemctl status nfs-server
systemctl enable rpcbind && systemctl enable nfs-server
```

## Client Validation

Before integrating NFS with Kubernetes, validate that a cluster node can mount the share.

### 1. Install Client Packages

Run the following on a K3s node:

```sh
apt update
apt install -y rpcbind nfs-
# check the remote mount.
showmount -e 192.168.52.12
systemctl enable nfs-client.target
```

### 2. Manual Mount

Using `mount` only attaches it to the kernel; the `mount` will be lost after a reboot.

```sh
mkdir -p /data/nfs-conf
# Each Host in monitor cluser
## create the mount folder on the host.
mkdir -p /data/nfs-data/monitor
mount -t nfs 192.168.52.12:/data/nfs-data/monitor/provisioner /data/nfs-data/monitor
mount -t nfs 192.168.52.12:/data/nfs-conf /data/nfs-conf

# Each Host in producer cluser
## create the mount folder on the host.
mkdir -p /data/nfs-data/producer
mount -t nfs 192.168.52.12:/data/nfs-data/producer/provisioner /data/nfs-data/producer
mount -t nfs 192.168.52.12:/data/nfs-conf /data/nfs-conf

# Options: unmount folder
umount /data/nfs-data/rancher
```

If the node needs a persistent host-level mount, add an `/etc/fstab` entry:

```text
# producer cluser
192.168.52.12:/data/nfs-data/producer/provisioner  /data/nfs-data/producer/provisioner  nfs  defaults,_netdev,x-systemd.automount,nofail  0  0
192.168.52.12:/data/nfs-conf  /data/nfs-conf  nfs  defaults,_netdev,x-systemd.automount,nofail  0  0

# monitor cluser
192.168.52.12:/data/nfs-data/monitor/provisioner  /data/nfs-data/monitor/provisioner  nfs  defaults,_netdev,x-systemd.automount,nofail  0  0
192.168.52.12:/data/nfs-conf  /data/nfs-conf  nfs  defaults,_netdev,x-systemd.automount,nofail  0  0
```

Notes:

- `_netdev`: wait for networking before mounting
- `x-systemd.automount`: mount on first access
- `nofail`: do not block boot on mount

Then Mount:

```sh
mount -a
```

## EXAMPLE: Dynamic Provisioning in K3s

The core Kubernetes flow is:

1. Deploy RBAC and Provisioner.
2. Create a `StorageClass` that points to the provisioner.
3. Create a `PersistentVolumeClaim`.
4. Let Kubernetes dynamically create the `PersistentVolume`.

When using this flow, you do not need to create a static `PersistentVolume` manually for each workload.

### 1. Deploy the RBAC and Provisioner

Create [`nfs-rbac.yaml`](../../examples/yaml/nfs-rbac.yaml)

Apply and verify:

```sh
kubectl apply -f nfs-monitor-rbac.yaml
# 1. check service account
kubectl get serviceaccount nfs-client-provisioner -n default
# 2. check cluster role
kubectl get clusterrole nfs-client-provisioner-clusterrole
kubectl describe clusterrole nfs-client-provisioner-clusterrole
# 3. check cluster role binding
kubectl get clusterrolebinding nfs-client-provisioner-clusterrolebinding
kubectl describe clusterrolebinding nfs-client-provisioner-clusterrolebinding
```

Create [`nfs-provisioner.yaml`](../../examples/yaml/nfs-provisioner.yaml)

Apply and verify:

```sh
kubectl apply -f nfs-monitor-provisioner.yaml
# check provisioner
kubectl get deploy nfs-client-provisioner
kubectl describe deploy nfs-client-provisioner
```

### 2. Create the StorageClass

Create [`nfs-storageclass.yaml`](../../examples/yaml/nfs-storageclass.yaml)

Apply and verify:

```sh
kubectl apply -f nfs-monitor-storageclass.yaml
kubectl get storageclass
```

## 3. Create a PersistentVolumeClaim

Create [`nfs-pvc.yaml`](../../examples/yaml/nfs-pvc.yaml)

Apply and verify:

```sh
kubectl apply -f nfs-pvc.yaml
kubectl get pvc, pv -n nfs
kubectl get pods -n nfs
```
