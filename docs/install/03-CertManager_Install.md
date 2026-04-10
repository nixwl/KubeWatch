# Cert-Manager Install

After completing the base K3s cluster deployment, install `cert-manager` to manage TLS certificates inside the cluster.

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

`cert-manager` extends Kubernetes with certificate lifecycle management. In a K3s environment, it is commonly used to:

- issue internal self-signed or CA-signed certificates
- renew certificates automatically
- store issued key pairs as Kubernetes `Secret` objects

This document focuses on the installation framework only. Issuer design, DNS validation, and application-specific certificate requests should be handled as follow-up tasks.

## Prerequisites

Before installing Cert-Manager, you need to install Helm.

```sh
# quick install
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
sudo ./get_helm.sh
```

Then add the required Helm chart repositories.

```sh
# add chart repositories
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo add stable http://mirror.azure.cn/kubernetes/charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stablecharts https://charts.helm.sh/stable

# check & update chart repositories
helm repo list
helm repo update
```

## Install Cert-Manager

> By default, it is installed only on the `producer` cluster.

### 1. Add the Helm Chart Repository

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

### 2. Create the Namespace

```sh
kubectl create namespace cert-manager
```

### 3. Install the Chart

> ! This operation is performed on the `master` node.

```shell
# 0. add 'KUBECONFIG'
sudo vim ~/.bashrc
## add:  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
source ~/.bashrc

# 1. downaload and apply cert-manager crd configuration files
curl -LO https://cert-manager.io/public-keys/cert-manager-keyring-2021-09-20-1020CF3C033D4F35BAE1C19E1226061C665DF13E.gpg
curl https://github.com/cert-manager/cert-manager/releases/download/v1.19.1/cert-manager.crds.yaml
kubectl apply -f cert-manager.crds.yaml

# 2. check cert-manager crd status
kubectl get crd | grep cert-manager.
```

For Producer Cluser:

```sh
helm install cert-manager jetstack/cert-manager  --version v1.9.1 --namespace cert-manager --verify --keyring /usr/share/keyrings/cert-manager-keyring-2021-09-20-1020CF3C033D4F35BAE1C19E1226061C665DF13E.gpg  --set crds.enabled=true
```

For Monitor Cluser:

```sh
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --version v1.19.1 --set installCRDs=true --set prometheus.enabled=false
```

## Option: Uninstall Cert-Manager

If you need to remove the installation:

```sh
helm uninstall cert-manager -n cert-manager
```

Check whether certificate-related resources still exist:

```sh
kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces
```

If you want a full cleanup for a lab rebuild, remove the CRDs after all dependent resources are deleted:

```sh
kubectl delete crd \
  issuers.cert-manager.io \
  clusterissuers.cert-manager.io \
  certificates.cert-manager.io \
  certificaterequests.cert-manager.io \
  orders.acme.cert-manager.io \
  challenges.acme.cert-manager.io
```

## Option: Self-Signed Domain Bootstrap

After installing `cert manager`, use a self-signed certificate to issue certificates.

1. Create a cluster-scoped self-signed ClusterIssuer.
2. Create a Certificate resource.
3. Create a CA Issuer.
4. Request a domain certificate.

### 1. Create a ClusterIssuer For CA

Create and apply [certmanager-cluster_issuer.yaml](../../examples/yaml/certmanager-cluster_issuer.yaml)

```sh
# create cluster issuer for CA
kubectl apply -f certmanager-cluster_issuer.yaml
# check cluster issuer status
kubectl get clusterissuers -o wide selfsigned-cluster-issuer
kubectl describe clusterissuer selfsigned-cluster-issuer
```

### 2. Create a Certificate For CA

Suitable when you want to issue certificates from your own CA inside the cluster.

Create and apply [certmanager-ca_certificate.yaml](../../examples/yaml/certmanager-ca_certificate.yaml)

```sh
# create certificate for CA
kubectl apply -f certmanager-ca_certificate.yaml

# check secret status and contents
kubectl get secret -n cert-manager | grep producer-ca-secret
kubectl get secret -n cert-manager -o yaml

# verify your CA secret, The output indicates that the certificate is a self-signed CA certificate, with both the Issuer and Subject set to CN=producer-ca, and it includes the CA:TRUE flag.
echo "<contents>" | base64 -d | openssl x509  -text -noout
```

### 3. Create a CA Issuer

Create and apply [certmanager-ca_issuer.yaml](../../examples/yaml/certmanager-ca_issuer.yaml)

```sh
# create a CA Issuer
kubectl apply -f certmanager-ca_issuer.yaml
# check clusterissuer
kubectl get clusterissuers -o wide
```

### 4. Request a domain certificate

Provide an example of manually requesting a domain certificate. Create and apply [certmanager-certificate.yaml](../../examples/yaml/certmanager-certificate.yaml)

```sh
# create certificate
kubectl apply -f certmanager-certificate.yaml
# verify secret status
kubectl get certificate -n kube-system
kubectl get secret -n kube-system | grep traefik-tls
```
