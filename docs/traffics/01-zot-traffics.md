# Zot Traffic Injection Design

This document summarizes the K6-based Zot traffic injection design used on the K3s cluster. The design targets a deployed Zot OCI registry and generates registry-oriented API traffic for validation, steady-state simulation, and periodic workload replay.

The related Zot platform deployment is described in [18-Zot-Deploy.md](../workload/18-Zot-Deploy.md).

## Objectives

The traffic injection design has four goals:

- Validate that the deployed Zot registry is reachable and behaves correctly through its OCI Registry API.
- Reproduce common registry access patterns such as health checks, repository discovery, tag browsing, manifest resolution, and blob fetching.
- Run one-off Jobs for scenario verification and hourly CronJobs for long-running workload replay.
- Produce K6 runtime metrics and log artifacts that can be correlated with cluster, ingress, cache, and storage monitoring data.

## Deployment Model & Scenario Architecture

The design uses a dedicated Kubernetes namespace, usually `traffic`, to isolate all K6 resources from the Zot application namespace.

- **ConfigMap**: stores K6 JavaScript scenario files and `repo-spec.json`.
- **Job**: runs a single scenario or a mixed scenario for ad hoc testing.
- **CronJob**: runs the mixed scenario on a schedule to simulate a full business day.
- [PersistentVolumeClaim](../../configs/traffics/k6-pvc.yaml): stores K6 output files for later inspection.
- [Secret](../../configs/traffics/k6-zot-secret.yaml): stores the Zot Basic Auth credentials.

Unlike the Gitea workload model, Zot traffic injection is entirely API-based. The scenario set maps directly to OCI Registry API paths instead of separating web and API layers.

The runtime design uses:

- A shared `lib.js` script for HTTP helpers, auth headers, repo selection, and blob batching.
- One `ConfigMap` per atomic scenario.
- A projected `/scripts` volume that mounts all scenario files into the K6 container.
- A `repo-spec.json` file that defines weighted repository pools for mixed runs.

Authentication is performed through Basic Auth headers built from `ZOT_USER` and `ZOT_PASS`. The source notes show admin credentials for setup and testing, but production workloads should inject credentials only through Kubernetes Secrets.

> - [k6-zot-lib-cm.yaml](../../configs/traffics/k6-zot-lib-cm.yaml)

## 1. Registry Traffic Scenarios

### 1.1 Ping

This scenario probes the registry liveness endpoint:

- `GET /v2/`

The script treats both `200` and `401` as valid liveness signals, which matches OCI registry behavior where unauthenticated access can still prove the endpoint is alive.

> - [k6-zot-ping-cm.yaml](../../configs/traffics/k6-zot-ping-cm.yaml)
> - [k6-zot-ping-job.yaml](../../configs/traffics/k6-zot-ping-job.yaml)

### 1.2 Catalog

This scenario queries the registry catalog:

- `GET /v2/_catalog?n=<limit>`

It represents light operator or UI-style repository discovery. The design accepts `404` as a non-fatal result because some registries disable catalog enumeration.

> - [k6-zot-catalog-cm.yaml](../../configs/traffics/k6-zot-catalog-cm.yaml)
> - [k6-zot-catalog-job.yaml](../../configs/traffics/k6-zot-catalog-job.yaml)

### 1.3 Tags

This scenario queries the tag list for a selected repository:

- `GET /v2/<repo>/tags/list?n=<limit>`

It models read-heavy tag browsing and is also used during setup and mixed runs to build a usable tag pool per repository.

> - [k6-zot-tags-cm.yaml](../../configs/traffics/k6-zot-tags-cm.yaml)
> - [k6-zot-tags-job.yaml](../../configs/traffics/k6-zot-tags-job.yaml)

### 1.4 Manifest

This scenario resolves image manifests and indexes:

- `HEAD /v2/<repo>/manifests/<tag-or-digest>`
- `GET /v2/<repo>/manifests/<tag-or-digest>`

The implementation first performs a `HEAD` request, then performs a probabilistic `GET` controlled by `MANIFEST_GET_PCT`. If the returned object is an OCI index or Docker manifest list, the script prefers the `linux/amd64` entry and recursively resolves the final manifest.

This scenario is the core metadata path for image pulls because it discovers the config digest and layer digests needed by the blob scenario.

> - [k6-zot-manifest-cm.yaml](../../configs/traffics/k6-zot-manifest-cm.yaml)
> - [k6-zot-manifest-job.yaml](../../configs/traffics/k6-zot-manifest-job.yaml)

### 1.5 Blobs

This scenario simulates image content access:

- `GET` or `HEAD /v2/<repo>/blobs/<digest>`

The script first resolves the manifest, then downloads the config blob plus either:

- A sampled subset of layers.
- All layers, with a low probability controlled by `PULL_FULL_PCT`.

Blob access is batched with configurable parallelism and mixes `GET` and `HEAD` according to `BLOB_GET_PCT`. This is the heaviest scenario and the main source of registry bandwidth in the workload model.

> - [k6-zot-blobs-cm.yaml](../../configs/traffics/k6-zot-blobs-cm.yaml)
> - [k6-zot-blobs-job.yaml](../../configs/traffics/k6-zot-blobs-job.yaml)

## 2. Mixed Workload Design

The atomic scenarios above are combined into a mixed workload intended to emulate realistic registry consumption rather than endpoint-isolated tests.

Conceptually, the source notes describe a pull-dominant workload where each iteration emphasizes:

- Pull-like traffic: about 70%
- Browse-like traffic: about 25%
- Catalog traffic: about 5%

The actual implementation does not use a single weighted random dispatcher. Instead, it uses K6 `constant-vus` scenarios with separate executors for:

- `pullScenario`
- `browseScenario`
- `catalogScenario`

This means the effective traffic mix is controlled by per-scenario VU counts and per-scenario behavior knobs, not only by one percentage table.

### 2.1 Repository Pool Design

The mixed scenario loads repository candidates from `repo-spec.json`. The source notes seed the pool with mirrored images such as:

- `mirror/docker.io/library/nginx`
- `mirror/docker.io/library/redis`
- `mirror/docker.io/library/alpine`
- `mirror/docker.io/library/busybox`
- `mirror/docker.io/library/debian`
- `mirror/docker.io/library/httpd`
- `mirror/ghcr.io/grafana/k6`

Each repository can be assigned a weight, and the script can also:

- Discover repositories from `_catalog`
- Discover tags dynamically from `tags/list`
- Filter repositories with allow and deny regexes
- Shuffle and cap the repository pool before the run starts

### 2.2 Mixed Job Baseline

The ad hoc mixed Job uses a general-purpose baseline profile:

| Parameter group | Baseline                                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------ |
| Duration        | `15m`                                                                                            |
| Scenario VUs    | `PULL_VUS=1`, `BROWSE_VUS=1`, `CATALOG_VUS=1`                                                    |
| Repo discovery  | `DISCOVER_REPOS=false`, `DISCOVER_TAGS=true`, `REQUIRE_TAGS=true`                                |
| Pool sizing     | `MAX_REPOS=50`, `SETUP_TAGS_LIST_N=200`                                                          |
| Browse behavior | `BROWSE_TAGS_LIST_PCT=30`, `BROWSE_MANIFEST_GET_PCT=70`                                          |
| Pull behavior   | `PULL_MANIFEST_GET_PCT=95`, `PULL_BLOB_GET_PCT=80`, `PULL_BLOB_PARALLELISM=2`, `PULL_FULL_PCT=5` |
| Think time      | `0.05s` to `0.25s`                                                                               |
| Thresholds      | failed rate `< 0.01`, p95 `< 1200 ms`                                                            |

This baseline is suitable for validating the end-to-end mixed orchestration before enabling the long-running scheduler.

> - [k6-zot-mixed-cm.yaml](../../configs/traffics/k6-zot-mixed-cm.yaml)
> - [k6-zot-mixed-job.yaml](../../configs/traffics/k6-zot-mixed-job.yaml)
> - [k6-zot-mixed-cron.yaml](../../configs/traffics/k6-zot-mixed-cron.yaml)

## 3. Scheduled Profiles

The hourly CronJob applies three profile families. In the YAML, the normal profile is named `high`, but functionally it represents regular daytime traffic between low and peak.

| Profile     | Duration | Pull VUs | Browse VUs | Catalog VUs | Think time         | Max repos | Thresholds                            |
| ----------- | -------- | -------: | ---------: | ----------: | ------------------ | --------: | ------------------------------------- |
| Low         | `55m`    |        1 |          0 |           0 | `0.80s` to `2.00s` |        20 | failed rate `< 0.02`, p95 `< 2500 ms` |
| High/Normal | `55m`    |        1 |          1 |           0 | `0.25s` to `0.90s` |        30 | failed rate `< 0.01`, p95 `< 1800 ms` |
| Peak        | `55m`    |        2 |          1 |           0 | `0.10s` to `0.40s` |        50 | failed rate `< 0.02`, p95 `< 2500 ms` |

As the profile increases from low to peak, the design also increases request depth:

- Larger setup-time tag scans.
- More frequent manifest `GET` operations.
- Higher blob download probability.
- More sampled layers, and a slightly higher chance of full-layer pulls.

The scheduled profiles keep `CATALOG_VUS=0`, so catalog traffic is effectively disabled in steady-state scheduled runs. This reflects a deliberate bias toward pull and browse behavior, which is closer to real registry consumption.

## 4. Scheduling Strategy

The mixed workload is designed to run as an hourly CronJob:

- One run starts every hour.
- Each run lasts about `55m`.
- The remaining time provides a buffer before the next run.
- `concurrencyPolicy: Forbid` prevents overlapping runs.

The source prose and the CronJob YAML are not fully identical, so the YAML should be treated as the effective schedule. The actual CronJob configuration uses:

- `PEAK_HOURS="17 18"`
- `LOW_HOURS="00 01 02 03 04 05 06 07 08 12 13 21 22 23"`
- All other hours fall into the regular `high` profile

This produces a small-cluster traffic model with light overnight activity, moderate daytime activity, and a focused late-afternoon peak.

## 5. Log And Artifact Retention

The scheduled run mounts a PVC, typically `k6-logs-pvc`, at `/logs` and writes output under a Zot-specific directory layout:

- `/logs/zot/<profile>/<YYYYMMDD>/summary-<run_id>.json`
- `/logs/zot/<profile>/<YYYYMMDD>/run-<run_id>.log`
- `/logs/zot/<profile>/<YYYYMMDD>/env-<run_id>.txt`

The CronJob captures the selected profile, time window, and effective runtime parameters in the environment dump. This is useful for comparing K6 results with:

- Zot server metrics
- Traefik ingress behavior
- Redis cache and session behavior
- MinIO-backed blob storage performance

## 6. Metrics And Acceptance Signals

The design relies on standard K6 metrics, especially:

- `http_req_duration`: end-to-end request latency
- `http_req_failed`: request failure rate
- `http_req_waiting`, `http_req_sending`, `http_req_connecting`, `http_req_tls_handshaking`: latency breakdown
- `iterations` and `iteration_duration`: scenario throughput and cycle time
- `vus`: active virtual users
- `data_received` and `data_sent`: transfer volume

The scripts also use K6 `check()` assertions to validate expected registry responses such as:

- Ping returning `200` or `401`
- Catalog returning `200` or `404`
- Tag list returning an allowed status set
- Manifest `HEAD` and `GET` returning `200`
- Blob access returning `200` or `307`

In practice, the most important acceptance signals are:

- The failure rate stays below the profile threshold.
- The `p95` latency stays within the configured limit.
- Manifest and blob checks continue to succeed while concurrency and request depth increase.

## Summary

The Zot traffic injection design is a K6-based OCI registry workload model for K3s. It breaks registry behavior into reusable scenario scripts for ping, catalog, tags, manifests, and blobs, then combines them into a pull-dominant mixed workload driven by repository pools and profile-specific VU allocations. One-off Jobs are used for scenario validation, while hourly CronJobs replay low, normal, and peak registry traffic and persist structured artifacts for later analysis.
