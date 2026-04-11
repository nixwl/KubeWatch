# Wiki Traffic Injection Design

This document summarizes the K6-based Wiki.js traffic injection design used on the K3s cluster. The design targets a deployed Wiki.js service and generates realistic GraphQL traffic for validation, steady-state simulation, and periodic workload replay.

The related Wiki.js platform deployment is described in [19-Wiki-Deploy.md](../workload/19-Wiki-Deploy.md).

## Objectives

The traffic injection design has four goals:

- Validate that the deployed Wiki.js instance is reachable and behaves correctly through its GraphQL API.
- Reproduce common knowledge-base activity such as listing pages, opening pages, searching content, and running controlled write operations.
- Run one-off Jobs for scenario verification and hourly CronJobs for long-running workload replay.
- Produce K6 runtime metrics and log artifacts that can be correlated with cluster, ingress, application, and database monitoring data.

## Deployment Model & Scenario Architecture

The design uses a dedicated Kubernetes namespace, usually `traffic`, to isolate all K6 resources from the Wiki.js application namespace.

- **ConfigMap**: stores shared defaults, scenario-specific environment settings, and K6 scripts.
- **Job**: runs a single scenario or a mixed scenario for ad hoc testing.
- **CronJob**` runs the mixed scenario on a schedule to simulate a full business day.
- [Secret](../../configs/traffics/k6-wiki-secret.yaml): stores the Wiki.js access token.
- [PersistentVolumeClaim](../../configs/traffics/k6-pvc.yaml): stores K6 output files for later inspection.

We define a shared [wiki-spec.json](../../configs/traffics/k6-wiki-secret.yaml) with common defaults such as locale, page ordering, and think-time ranges. In the current repository, the operational K6 resources are organized as scenario-specific `env + script + job` files plus a mixed workload entrypoint.

The runtime design uses:

- Dedicated GraphQL scripts for each atomic scenario.
- One environment `ConfigMap` per scenario.
- A mixed entry script that imports all six scenario scripts.
- A projected script volume assembled by an `initContainer` for mixed runs.

Authentication is performed through a Bearer token injected from [k6-wiki-secret](../../configs/traffics/k6-wiki-secret.yaml). The source notes show a raw admin token for setup, but production workloads should inject tokens only through Kubernetes Secrets.

## 1. Read Traffic Scenarios

### 1.1 Pages List

This scenario simulates a user browsing the wiki catalog:

- Query the `pages.list` GraphQL API.
- Return page identifiers, paths, and titles.
- Apply optional filters such as `locale` and `orderBy`.

It represents the lightest read path and is useful for validating token access, GraphQL reachability, and general page inventory queries.

> - [k6-wiki-pageslist-env.yaml](../../configs/traffics/k6-wiki-pageslist-env.yaml)
> - [k6-wiki-pageslist-script.yaml](../../configs/traffics/k6-wiki-pageslist-script.yaml)
> - [k6-wiki-pageslist-job.yaml](../../configs/traffics/k6-wiki-pageslist-job.yaml)

### 1.2 Page Read

This scenario simulates reading a page after selecting it from a page pool:

- Query `pages.list` during setup to build a candidate pool.
- Query `pages.single(id)` during execution.
- Optionally include fields such as `content`, `description`, `render`, and `toc`.

The script contains compatibility probes for optional fields and explicitly handles a known `toc` type mismatch pattern by disabling that field if the backend returns an incompatible schema response.

This scenario is the main content-read path and should be treated as the baseline for user-facing page consumption.

> - [k6-wiki-pagesread-env.yaml](../../configs/traffics/k6-wiki-pagesread-env.yaml)
> - [k6-wiki-pagesread-script.yaml](../../configs/traffics/k6-wiki-pagesread-script.yaml)
> - [k6-wiki-pagesread-job.yaml](../../configs/traffics/k6-wiki-pagesread-job.yaml)

### 1.3 Page Search

This scenario simulates site search:

- Query `pages.search(path, locale, query)`.
- Rotate across configured search terms.
- Validate that the result set is returned without GraphQL errors.

It models one of the more common interactive behaviors in documentation systems because search is often the entrypoint to page reads.

> - [k6-wiki-pagesearch-env.yaml](../../configs/traffics/k6-wiki-pagesearch-env.yaml)
> - [k6-wiki-pagesearch-script.yaml](../../configs/traffics/k6-wiki-pagesearch-script.yaml)
> - [k6-wiki-pagesearch-job.yaml](../../configs/traffics/k6-wiki-pagesearch-job.yaml)

## 2. Mutation Scenarios

The write scenarios are intentionally guarded so they do not modify arbitrary production pages. They operate only on pages created by the K6 write workflow.

### 2.1 Page Create

This scenario creates synthetic pages under a dedicated namespace:

- Create pages under a prefix such as `k6/create`.
- Add a generated `run_id` and VU-specific markers.
- Attach identifying tags such as `k6`, `loadtest`, and `create`.

This establishes the page pool used by later update and delete scenarios.

> - [k6-wiki-pagecreate-env.yaml](../../configs/traffics/k6-wiki-pagecreate-env.yaml)
> - [k6-wiki-pagecreate-script.yaml](../../configs/traffics/k6-wiki-pagecreate-script.yaml)
> - [k6-wiki-pagecreate-job.yaml](../../configs/traffics/k6-wiki-pagecreate-job.yaml)

### 2.2 Page Update

This scenario updates only pages that match the K6 create fingerprint:

- Restrict candidates to a configured `PATH_PREFIX`, typically `k6/create/`.
- Require identifying markers such as a specific tag, description, and content substring.
- Patch content inside bounded markers instead of rewriting the whole page arbitrarily.

The script dynamically discovers candidate pages during mixed runs so that update traffic can begin after create traffic has already started producing data.

> - [k6-wiki-pageupdate-env.yaml](../../configs/traffics/k6-wiki-pageupdate-env.yaml)
> - [k6-wiki-pageupdate-script.yaml](../../configs/traffics/k6-wiki-pageupdate-script.yaml)
> - [k6-wiki-pageupdate-job.yaml](../../configs/traffics/k6-wiki-pageupdate-job.yaml)

### 2.3 Page Delete

This scenario deletes only pages inside the controlled K6 namespace:

- Restrict candidates by `DELETE_PATH_PREFIX` and optional title filtering.
- Use `per-vu-iterations` and VU-based slicing to avoid duplicate delete attempts.
- Verify existence before delete and tolerate already-missing pages without treating them as failures.

In mixed mode, the delete script can rediscover candidates periodically so it can clean up pages created earlier in the same run.

> - [k6-wiki-pagedelete-env.yaml](../../configs/traffics/k6-wiki-pagedelete-env.yaml)
> - [k6-wiki-pagedelete-script.yaml](../../configs/traffics/k6-wiki-pagedelete-script.yaml)
> - [k6-wiki-pagedelete-job.yaml](../../configs/traffics/k6-wiki-pagedelete-job.yaml)

## 3. Mixed Workload Design

The six atomic scenarios above are combined into a mixed workload intended to approximate real Wiki.js usage while keeping write traffic tightly controlled.

The mixed entry script:

- Imports all six scenario scripts.
- Runs each scenario as its own `constant-vus` executor.
- Calls each sub-script `setup()` once to build shared runtime state.
- Splits the total VU budget across scenarios using fixed allocations and weighted allocation for the remainder.

For mixed execution, a Job or CronJob assembles these scripts into `/scripts`:

- `wiki_mixed.js`
- `pages_list.js`
- `page_read.js`
- `page_search.js`
- `page_create.js`
- `page_update.js`
- `page_delete.js`

The write-side isolation model uses per-run identifiers:

- `CREATE_RUN_ID`
- `REQUIRE_RUN_ID`
- `DELETE_RUN_ID`

This ensures that create, update, and delete operations stay scoped to pages created by the current synthetic workload instead of touching unrelated wiki content.

The ad hoc mixed Job uses a general-purpose baseline profile:

| Parameter group   | Baseline                                                                           |
| ----------------- | ---------------------------------------------------------------------------------- |
| Duration          | `10m`                                                                              |
| Total VUs         | `10`                                                                               |
| Weighted mix      | `W_LIST=15`, `W_READ=45`, `W_SEARCH=20`, `W_CREATE=5`, `W_UPDATE=10`, `W_DELETE=5` |
| Fixed VUs         | disabled by default (`VUS_* = 0`)                                                  |
| Shared think time | `500 ms` to `2500 ms`                                                              |
| Thresholds        | failed rate `< 0.01`, p95 `< 3000 ms`, checks `> 0.95`                             |

This baseline is intended for functional verification of the multi-scenario orchestration before switching to the long-running scheduler.

> - [k6-wiki-mix-env.yaml](../../configs/traffics/k6-wiki-mix-env.yaml)
> - [k6-wiki-mix-scripts.yaml](../../configs/traffics/k6-wiki-mix-scripts.yaml)
> - [k6-wiki-mix-job.yaml](../../configs/traffics/k6-wiki-mix-job.yaml)
> - [k6-wiki-mix-cron.yaml](../../configs/traffics/k6-wiki-mix-cron.yaml)

## 4. Scheduled Profiles

The source notes define three business-day profiles for the mixed workload.

| Profile  | Duration |                         Total VUs | Write VUs                                                       | Read/Search/List weights                    | Think time                        | Thresholds                                                    |
| -------- | -------- | --------------------------------: | --------------------------------------------------------------- | ------------------------------------------- | --------------------------------- | ------------------------------------------------------------- |
| Off-peak | `55m`    |                                 4 | source notes: writes disabled; CronJob YAML: `1/1/1` kept alive | notes: `70/20/10`; CronJob YAML: `60/25/15` | source notes: `1200` to `3500 ms` | source notes: fail `< 0.02`, p95 `< 2500 ms`, checks `> 0.97` |
| Normal   | `55m`    |   8 in notes, `6` in CronJob YAML | `1/1/1`                                                         | notes: `55/30/15`; CronJob YAML: `55/30/15` | source notes: `800` to `2500 ms`  | source notes: fail `< 0.01`, p95 `< 3000 ms`, checks `> 0.95` |
| Peak     | `55m`    | 12 in notes, `10` in CronJob YAML | `1/1/1`                                                         | notes: `50/35/15`; CronJob YAML: `45/35/20` | source notes: `400` to `1500 ms`  | source notes: fail `< 0.03`, p95 `< 4500 ms`, checks `> 0.93` |

There is a real difference between the prose notes and the current CronJob YAML:

- The prose says off-peak should disable writes entirely.
- The CronJob keeps `VUS_CREATE=1`, `VUS_UPDATE=1`, and `VUS_DELETE=1` even in the low profile.
- The prose uses larger total VU values than the shipped CronJob.

For implementation truth, the CronJob YAML should be treated as authoritative unless the schedule is intentionally revised.

## 5. Scheduling Strategy

The mixed workload is designed to run as an hourly CronJob:

- One run starts every hour.
- Each run lasts about `55m`.
- `concurrencyPolicy: Forbid` prevents overlapping runs.
- A PVC-backed output directory preserves run logs and summaries.

The source notes describe three time windows:

- Peak: around `09-11` and `14-17`
- Normal: the remaining business hours
- Off-peak: overnight hours

The current CronJob YAML uses a different effective schedule:

- `PEAK_HOURS="17 18"`
- `LOW_HOURS="00 01 02 03 04 05 06 07 08 12 13 21 22 23"`
- All other hours fall into the `normal` profile

This means the implemented schedule is lighter than the source concept and is optimized for a smaller cluster footprint.

## 6. Log And Artifact Retention

The scheduled run mounts a PVC, typically `k6-logs-pvc`, at `/logs` and writes output under a Wiki-specific directory layout:

- `/logs/wiki/<profile>/<YYYYMMDD>/summary-<run_id>.json`
- `/logs/wiki/<profile>/<YYYYMMDD>/run-<run_id>.log`
- `/logs/wiki/<profile>/<YYYYMMDD>/env-<run_id>.txt`

The CronJob stores the selected profile and effective environment values for each run. This makes it possible to correlate K6 output with:

- Wiki.js application metrics
- Traefik ingress metrics
- PostgreSQL load and lock behavior
- Cluster resource saturation

## 7. Metrics And Acceptance Signals

The design relies on standard K6 metrics, especially:

- `http_req_duration`: end-to-end request latency
- `http_req_failed`: request failure rate
- `checks`: GraphQL and workflow assertions
- `iterations` and `iteration_duration`: scenario throughput and cycle time
- `vus`: active virtual users
- `data_received` and `data_sent`: traffic volume

The scripts also use K6 `check()` assertions to validate:

- HTTP status is `200`
- No GraphQL errors are returned
- Expected objects such as `pages.list`, `pages.single`, and `pages.search.results` are present
- Mutation response results report `succeeded === true`

In practice, the most important acceptance signals are:

- The failure rate stays below the configured threshold.
- The `p95` latency stays within the profile limit.
- Read scenarios continue returning stable GraphQL shapes.
- Write scenarios only touch K6-owned pages and do not leak into real content.

## Summary

The Wiki.js traffic injection design is a K6-based GraphQL workload model for K3s. It separates user behavior into reusable scripts for listing, reading, searching, creating, updating, and deleting pages, then combines them into a multi-scenario mixed workload driven by weighted and fixed VU allocation. One-off Jobs validate individual scenarios, while hourly CronJobs replay low, normal, and peak traffic and persist structured artifacts for later analysis.
