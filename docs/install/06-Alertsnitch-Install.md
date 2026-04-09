# [Alertsnitch](https://github.com/yakshaving-art/alertsnitch.git) Install

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

As a core component of the Prometheus ecosystem, Prometheus Alertmanager focuses primarily on receiving, deduplicating, grouping, and routing real-time alerts. While its design omits persistent storage for alert data to minimize system complexity, this architectural choice also introduces certain limitations.

Alertsnitch is used to persist historical alert data from Alertmanager for subsequent anomaly analysis and annotation

## Prerequisites

Complete the following first:

- [Kubernetes Deployment](../deploy/00-Kubernetes_Deployment.md)
- [NFS Deployment](../deploy/01-NFS_Deployment.md)
- [DNS Deployment](../deploy/02-DNS_Deployment.md)
- [Cert-Manager Install](./03-CertManager_Install.md)
- [Rancher Install](./04-Rancher-Install.md)
- [Prometheus Stack Install](./05-PrometheusStack-Install.md)

## Configure Alertmanager Receiver

The repository already includes an Alertmanager configuration fragment for webhook delivery:

- [monitor-alertmanager-alerts.yaml](../../configs/pipelines/prometheus_stack-install/monitor-alertmanager-alerts.yaml)
- [monitor-kube-prometheus-stack-values.yaml](../../configs/pipelines/prometheus_stack-install/monitor-kube-prometheus-stack-values.yaml)

The relevant receiver definition is:

```yaml
alertmanager:
  config:
    receivers:
      - name: "null"
      - name: "email.hook"
        email_configs:
          - to: "xxx@xxx.com"
            send_resolved: false
      - name: "web.hook"
        webhook_configs:
          - url: "http://alertsnitch.example.com/webhook"
            send_resolved: true
    route:
      group_by:
        - namespace
        - cluster
        - alertname
      group_interval: 5m
      group_wait: 30s
      receiver: "null"
      repeat_interval: 12h
      routes:
        - matchers:
            - alertname = "Watchdog"
          receiver: "null"
          continue: false
        - receiver: "email.hook"
          continue: true
        - receiver: "web.hook"
          continue: false
```

## Deploy Alertsnitch

### 1. Create DataBase

> The database should be installed on host edb1.

First, download the SQL script.

```sh
wget https://raw.githubusercontent.com/yakshaving-art/alertsnitch/master/db.d/mysql/0.0.1-bootstrap.sql
wget https://raw.githubusercontent.com/yakshaving-art/alertsnitch/master/db.d/mysql/0.1.0-fingerprint.sql
```

Then, create the database and initialize it using the SQL script.

```sql
mysql -u root -p
-- create database
CREATE DATABASE alertsnitch CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
-- create user
CREATE USER 'alertsnitch'@'%' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON alertsnitch.* TO 'alertsnitch'@'%';
ALTER USER 'alertsnitch'@'%' IDENTIFIED WITH mysql_native_password BY '<password>';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'alertsnitch'@'%';
```

```sh
# initialize database
mysql -u root -p alertsnitch < ./0.0.1-bootstrap.sql
mysql -u root -p alertsnitch < ./0.1.0-fingerprint.sql
```

> A complete script can handle the entire process described above.
> [init-database.sh](../../scripts/pipelines/alertsnitch-install/init-database.sh)

### 2. Install Alertsnitch On Monitor Cluster

Install Alertsnitch into the monitor cluster using our complete deployment configuration.

> [alertsnitch-deployment.yaml](../../configs/pipelines/alertsnitch-install/alertsnitch-deployment.yaml)

```sh
# deploy alertsnitch
kubectl apply -f alertsnitch-deployment.yaml
# healthy check: should response HTTP 200
curl -vk http://alertsnitch.example.com/-/ready
curl -vk http://alertsnitch.example.com/-/health
```

### 3. Link to AlertManger

Add a webhook to Alertmanager to push alert data to the corresponding Alertsnitch API.

```Yaml
receivers:
 - name: "web.hook"
   webhook_configs:
     - url: "http://alertsnitch.example.com/webhook"
       send_resolved: true
route:
 group_by:
 - namespace
 - cluster
 - alertname
 group_interval: 5m
 group_wait: 30s
 receiver: "null"
 repeat_interval: 12h
routes:
  - matchers:
    - alertname = "Watchdog"
      receiver: "null"
      continue: false
  - receiver: "email.hook"
    continue: true
  - receiver: "web.hook"
    continue: false
```
