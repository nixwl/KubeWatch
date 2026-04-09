# InfluxDB Deployment

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

Prometheus's built-in time-series database (TSDB) is highly convenient to use, but its primary drawback is the difficulty of maintenance. If data corruption occurs, recovery often requires deleting the storage directory, recreating it, and restarting Prometheus to restore normalcy.

Furthermore, the native Prometheus TSDB is not suitable for storing vast amounts of historical data and lacks the flexibility to scale. To address this, Prometheus offers Remote Storage solutions, allowing data to be offloaded to external time-series databases such as InfluxDB or OpenTSDB.

- InfluxDB V1: Provides a Remote Write API that allows Prometheus to write data directly.
- InfluxDB V2: Stores Prometheus monitoring data in InfluxDB via Telegraf.
- InfluxDB V3: Its key feature is the use of Object Storage to store time-series data in Apache Parquet format.

In this guide, we will adopt InfluxDB V2 as our time-series metrics storage solution.

## Install InfluxDB V2 OSS

> InfluxDB is deployed on `edb1`

### 1. Install influxData Key

Download influxdata-archive.key

```sh
curl --silent --location -O https://repos.influxdata.com/influxdata-archive.
# sha256 verify
echo "943666881a1b8d9b849b74caebf02d3465d6beb716510d86a39f6c8e8dac7515  influxdata-archive.key" \
| sha256sum --check - && cat influxdata-archive.key \
| gpg --dearmor \
| tee /etc/apt/trusted.gpg.d/influxdata-archive.gpg > /dev/null \
&& echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' \
| tee /etc/apt/sources.list.d/influxdata.list
```

### 2. Install InfluxDB V2

```sh
sudo apt-get update
sudo apt-get install influxdb2
# enable and restart
systemctl enable influxdb.service
systemctl restart influxdb.service
```

Once the installation is complete, you can access the UI at 192.168.52.8:8086. Configure the following settings:

- User & Password
- Organization: we set `data-center`
- Initial Bucket: monitor

Next, obtain the Operator API Token first

## Configure InfluxDB V2

Subsequently, when using influxd configuration flags, custom environment variables, or defining options in a configuration file, the CLI must be configured with the Operator token.

```sh
influx config create \
	--config-name localhost \
	--host-url http://127.0.0.1:8086 \
	--org data-center \
	--token '<token>' \
	--active
```

First, check the currently loaded configuration, then modify the configuration file.

```sh
# find system configuration location
cat /etc/default/influxdb2
# configure
vim /etc/influxdb/config.toml
```

Disable metrics-disabled to stop collecting internal metrics, then disable telemetry."

```toml
bolt-path = "/var/lib/influxdb/influxd.bolt"
engine-path = "/var/lib/influxdb/engine"
metrics-disabled = true
reporting-disabled = true
```

Then, configure the query and storage settings.

```toml
# query settings:
query-concurrency = 2
query-queue-size = 10
## 32MB ~ 256MB
query-memory-bytes = 268435456
query-initial-memory-bytes = 33554432
## 512MB
query-max-memory-bytes = 536870912

# storage settings:
## 128M
storage-cache-max-memory-size = 134217728
## 16MB
storage-cache-snapshot-memory-size = 16777216
storage-cache-snapshot-write-cold-duration = "5m0s"
storage-max-index-log-file-size = 524288
storage-series-id-set-cache-size = 100
storage-max-concurrent-compactions = 1
storage-series-file-max-concurrent-snapshot-compactions = 1
```

Then, load and apply the configuration

```sh
systemctl restart influxdb.service
influx server-config
```

## Bucket Settings

We have configured four buckets: `producer`, `monitor`, `producer.daily`, and `monitor.daily`. The daily buckets store 24 hours of data to facilitate efficient exports. This approach avoids the time overhead and memory pressure associated with querying a high-capacity bucket during data extraction.

Data is sent from Prometheus via Telegraf to the producer and monitor buckets. Therefore, bucket tasks must be configured to distribute data from these primary buckets to the producer.daily and monitor.daily buckets.

The core design approach is to replicate data from the full-capacity bucket into a daily bucket. This daily bucket is updated dynamically at regular intervals with a 15-minute time window, transferring 15 minutes of data per run. We apply a 2-minute offset to delay execution, ensuring that Telegraf's late-arriving (tail) data is fully ingested. Additionally, the window overlap is set to 20 minutes.

For monitor bucket:

```Flux
import "date"
import "timezone"
option task = {
  name: "monitor.daily.schedule",
  every: 15m,
  offset: 2m
}


stop  = date.truncate(t: now(), unit: 15m)

start = date.add(d: -20m, to: stop)

from(bucket: "monitor")
  |> range(start: start, stop: stop)
  |> to(bucket: "monitor.daily", org: "data-center")
```

For producer bucket:

```Flux
import "date"
import "timezone"
option task = {
  name: "producer.daily.schedule",
  every: 15m,
  offset: 2m
}

stop  = date.truncate(t: now(), unit: 15m)

start = date.add(d: -20m, to: stop)

from(bucket: "producer")
  |> range(start: start, stop: stop)
  |> to(bucket: "producer.daily", org: "data-center")
```

To perform regular data exports, we extract data directly from the daily bucket and save it in CSV format.

> [daily_export.sh](../../scripts/pipelines/influxdb-deploy/daily_export.sh)

Then, configure a scheduled task to run at the 15th minute of every hour.

```sh
crontab -e
# add
##  15 * * * * /bin/bash -lc '/bin/bash /root/influxDB/v2/cron_csv.sh > /root/influxDB/v2/log/cron_csv_$(TZ=Asia/Shanghai date +\%Y\%m\%d_\%H\%M\%S).log 2>&1'
```
