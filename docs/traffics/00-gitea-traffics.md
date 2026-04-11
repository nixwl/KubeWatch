# Gitea Traffic Injection Design

This document summarizes the K6-based Gitea traffic injection design used on the K3s cluster. The design targets a deployed Gitea service and generates realistic web and API traffic for validation, steady-state simulation, and periodic workload replay.

The related Gitea platform deployment is described in [16-Gitea-Deploy.md](../workload/16-Gitea-Deploy.md).

## Objectives

The traffic injection design has four goals:

- Validate that the deployed Gitea instance is reachable and behaves correctly through both the web UI and the REST API.
- Reproduce common developer activity such as browsing repositories, reading pull requests, inspecting commits, and viewing issues.
- Run one-off Jobs for scenario verification and hourly CronJobs for long-running workload replay.
- Produce K6 runtime metrics and structured log artifacts that can be correlated with cluster and application monitoring data.

## Deployment Model & Scenario Architecture

The design uses a dedicated Kubernetes namespace, usually `traffic`, to isolate all K6 resources from the Gitea application namespace. The traffic generator is deployed in the external cluster (Monitor) to simulate access originating from outside the network.

- **ConfigMap**: stores K6 JavaScript scenario files.
- **Job**: runs a single scenario or a mixed scenario for ad hoc testing.
- **CronJob**: runs the mixed scenario on a schedule to simulate a full business day.
- [Secret](../../configs/traffics/k6-gitea-secret.yaml): stores the Gitea token and, when required, username and password for UI login.
- [PersistentVolumeClaim](../../configs/traffics/k6-pvc.yaml): stores K6 output files for later inspection.

The traffic model is split into two layers:

- Web traffic: browser-like navigation through the Gitea UI.
- API traffic: direct calls to Gitea REST endpoints.

Each atomic scenario is packaged as a dedicated script `ConfigMap`. Mixed scenarios assemble several atomic scripts into one entrypoint.

For mixed runs, the design uses an `initContainer` to copy multiple scripts from mounted `ConfigMap` volumes into `/scripts` backed by `emptyDir`. The main K6 container then starts only the mixed entry script, such as `web_mix.js` or the API mixed script.

## 1. Web Traffic Scenarios

### 1.1 Web Review

This scenario simulates a reviewer using the Gitea web interface:

- Log in through the UI.
- Open the home page.
- Enter a repository.
- Browse source files.
- Open pull request pages for review-oriented read traffic.

This scenario is intended to exercise the HTML pages, redirects, session handling, and pull request rendering path.

> - [k6-gitea-web-review-scripts-configmap.yaml](../../configs/traffics/k6-gitea-web-review-scripts-configmap.yaml)
> - [k6-gitea-web-review-scripts-job.yaml](../../configs/traffics/k6-gitea-web-review-scripts-job.yaml)

### 1.2 Web Browse

This scenario simulates lightweight repository exploration:

- Log in first.
- Browse the home page or the Explore page.
- Query repositories, users, and organizations.
- Open a randomly selected repository and visit enabled subsections.

This represents the most common low-cost read traffic in the UI.

> - [k6-gitea-web-browse-scripts-configmap.yaml](../../configs/traffics/k6-gitea-web-browse-scripts-configmap.yaml)
> - [k6-gitea-web-browse-scripts-job.yaml](../../configs/traffics/k6-gitea-web-browse-scripts-job.yaml)

### 1.3 Web Issues

This scenario focuses on issue pages. A virtual user randomly selects an issue and opens its detail page. The main purpose is to inject issue read traffic without the heavier cost of commit or review navigation.

> - [k6-gitea-web-issues-scripts-configmap.yaml](../../configs/traffics/k6-gitea-web-issues-scripts-configmap.yaml)
> - [k6-gitea-web-issues-scripts-job.yaml](../../configs/traffics/k6-gitea-web-issues-scripts-job.yaml)

### 1.4 Web Commit

This scenario targets repository history and file inspection:

- Commit list pages.
- Commit detail pages.
- Diff and patch views.
- Path-specific commit history.
- File content access at a selected commit.

The source profiles progressively increase the probability of expensive commit-detail, diff, patch, and blame-style reads under heavier traffic.

> - [k6-gitea-web-commit-scripts-configmap.yaml](../../configs/traffics/k6-gitea-web-commit-scripts-configmap.yaml)
> - [k6-gitea-web-commit-scripts-job.yaml](../../configs/traffics/k6-gitea-web-commit-scripts-job.yaml)

## 2. API Traffic Scenarios

### 2.1 API Auth

This scenario validates the authenticated API path:

- `GET /api/v1/version`
- `GET /api/v1/user/repos`
- `GET /api/v1/user`

It is primarily a connectivity and authorization check.

> - [k6-gitea-api-auth-scripts-configmap.yaml](../../configs/traffics/k6-gitea-api-auth-scripts-configmap.yaml)
> - [k6-gitea-api-auth-scripts-job.yaml](../../configs/traffics/k6-gitea-api-auth-scripts-job.yaml)

### 2.2 API Repository Browse

This scenario reads repository metadata and paginated lists:

- Repository metadata.
- Branch and tag lists.
- User repository lists.

It represents routine API-driven repository browsing.

> - [k6-gitea-api-browse-scripts-configmap.yaml](../../configs/traffics/k6-gitea-api-browse-scripts-configmap.yaml)
> - [k6-gitea-api-browse-scripts-job.yaml](../../configs/traffics/k6-gitea-api-browse-scripts-job.yaml)

### 2.3 API Git Data

This scenario reads Git-oriented data:

- Commit lists.
- Commit detail payloads.
- File contents or raw content endpoints.

It is the API-side counterpart to the web commit scenario.

> - [k6-gitea-api-gitdata-scripts-configmap.yaml](../../configs/traffics/k6-gitea-api-gitdata-scripts-configmap.yaml)
> - [k6-gitea-api-gitdata-scripts-job.yaml](../../configs/traffics/k6-gitea-api-gitdata-scripts-job.yaml)

### 2.4 API Issues

This scenario covers issue-oriented API activity:

- Issue list, detail, and comments.
- Low-ratio write operations such as creating an issue, adding a comment, and optionally closing it.
- Cleanup after write tests so the repository is not left with uncontrolled synthetic data.

> - [k6-gitea-api-issues-scripts-configmap.yaml](../../configs/traffics/k6-gitea-api-issues-scripts-configmap.yaml)
> - [k6-gitea-api-issues-scripts-job.yaml](../../configs/traffics/k6-gitea-api-issues-scripts-job.yaml)

### 2.5 API Review

This scenario covers pull request review traffic:

- Pull request lists and details.
- Review lists.
- Review comments.
- Optional issue comments associated with the pull request discussion flow.

> - [k6-gitea-api-review-scripts-configmap.yaml](../../configs/traffics/k6-gitea-api-review-scripts-configmap.yaml)
> - [k6-gitea-api-issues-scripts-job.yaml](../../configs/traffics/k6-gitea-api-review-scripts-job.yaml)

## 3. Mixed Workload Design

The atomic scenarios above are combined into weighted mixed workloads. This allows one K6 run to approximate the behavior of a small development team instead of benchmarking a single endpoint family in isolation.

### 3.1 Web Mixed Profiles

The source notes define three web traffic profiles that scale concurrency, navigation depth, and tolerance thresholds.

| Profile  | VUs | Sleep | Browse | Review | Issues | Commit | Target thresholds                              |
| -------- | --: | ----: | -----: | -----: | -----: | -----: | ---------------------------------------------- |
| Off-peak |   5 |    2s |    60% |    15% |    20% |     5% | fail rate <= 3%, p95 <= 2500 ms, checks >= 97% |
| Normal   |  10 |    1s |    50% |    20% |    20% |    10% | fail rate <= 2%, p95 <= 2000 ms, checks >= 98% |
| Peak     |  20 |  0.5s |    40% |    25% |    20% |    15% | fail rate <= 5%, p95 <= 3000 ms, checks >= 95% |

As the profile increases from off-peak to peak, the scenario also enables deeper browsing:

- More explore, issue, and commit pages are visited.
- Commit detail and diff views become more frequent.
- Optional heavy paths such as patch views and blame-related reads are enabled at the highest level.

> - [k6-gitea-web-mixed-scripts-configmap.yaml](../../configs/traffics/k6-gitea-web-mixed-scripts-configmap.yaml)
> - [k6-gitea-web-mixed-scripts-job.yaml](../../configs/traffics/k6-gitea-web-mixed-scripts-job.yaml)
> - [k6-gitea-web-mixed-script-cronjob.yaml](../../configs/traffics/k6-gitea-web-mixed-script-cronjob.yaml)

### 3.2 API Mixed Profiles

The API side follows the same profile pattern but emphasizes paginated reads with a small controlled write ratio.

| Profile  | VUs | Sleep | Browse | Review | Issues | Git Data | Write ratio | Target thresholds                               |
| -------- | --: | ----: | -----: | -----: | -----: | -------: | ----------: | ----------------------------------------------- |
| Off-peak |   2 |    4s |    70% |    10% |    15% |       5% |       0.003 | fail rate <= 10%, p95 <= 5000 ms, checks >= 90% |
| Normal   |   6 |    2s |    55% |    20% |    20% |       5% |        0.01 | fail rate <= 5%, p95 <= 3000 ms, checks >= 95%  |
| Peak     |  10 |    1s |    40% |    30% |    20% |      10% |        0.02 | fail rate <= 8%, p95 <= 4500 ms, checks >= 93%  |

The source notes also describe a generic API mixed ratio that can include a small authentication-validation slice. In the scheduled profiles, `W_AUTH` is set to `0`, so steady-state runs focus on business traffic instead of repeated auth checks.

> - [k6-gitea-api-mixed-scripts-configmap.yaml](../../configs/traffics/k6-gitea-api-mixed-scripts-configmap.yaml)
> - [k6-gitea-api-mixed-scripts-job.yaml](../../configs/traffics/k6-gitea-api-mixed-scripts-job.yaml)
> - [k6-gitea-api-mixed-script-cronjob.yaml](../../configs/traffics/k6-gitea-api-mixed-scripts-cronjob.yaml)

## 4. Scheduling Strategy

The mixed workloads are designed to run as hourly CronJobs:

- One run starts every hour.
- Each run lasts about `55m`.
- The remaining `5m` provides a buffer before the next run.

The day is split into off-peak, normal, and peak windows. The source schedule examples imply a workday-shaped pattern, with higher traffic in late afternoon peak hours, lighter traffic overnight and around lunch, and normal traffic during the remaining daytime periods.

This scheduling model is intended to emulate a small Gitea-backed development team rather than a pure synthetic stress test.

## 5. Log And Artifact Retention

To preserve outputs, the design creates a PVC similar to `k6-logs-pvc` and mounts it into the workload pod. The recorded artifacts follow this structure:

- `/logs/<profile>/<YYYYMMDD>/summary-*.json`: machine-readable K6 summary output.
- `/logs/<profile>/<YYYYMMDD>/run-*.log`: raw console log for the run.
- `/logs/<profile>/<YYYYMMDD>/env-*.txt`: captured runtime parameters for the selected profile.

This makes it possible to compare application metrics, cluster metrics, and K6 output for the same time window.

## Metrics And Acceptance Signals

The source notes rely on standard K6 metrics to evaluate scenario health:

- `checks`: business assertions defined in the scripts.
- `http_req_duration`: end-to-end request latency.
- `http_req_failed`: request failure rate.
- `http_req_waiting`, `http_req_sending`, `http_req_connecting`, `http_req_tls_handshaking`: latency breakdown.
- `iterations` and `iteration_duration`: scenario throughput and cycle time.
- `vus`: active virtual users.
- `data_received` and `data_sent`: workload transfer volume.

In practice, the most important acceptance signals are:

- The scripted checks stay above the configured minimum.
- The failure rate remains below the profile threshold.
- The `p95` latency stays within the profile-specific objective.

## Summary

The Gitea traffic injection design is a layered K6 workload model for K3s. It separates web and API traffic into reusable scenario scripts, combines them through weighted mixed profiles, runs them as ad hoc Jobs or hourly CronJobs, and persists logs and summaries for later analysis. The result is a practical workload replay framework for validating Gitea behavior under realistic developer activity instead of endpoint-isolated microbenchmarks.
