# ChaosBlade Node Injection

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

The node injection implementation is organized as a small delivery framework rather than as isolated YAML files. Each scenario is composed from:

- a parameterized ChaosBlade template
- an environment `ConfigMap`
- a runner script `ConfigMap`
- a manual `Job`
- a scheduled `CronJob`
- a helper shell script that installs, patches, runs, and cleans up the scenario
- an optional launcher shell that sets concrete defaults for a lab run

Primary sources:

- [Node YAML Assets](../../configs/anomaly)
- [Node Shell Assets](../../scripts/anomaly)
- [ChaosBlade Install](../install/21-Chaosblade-Install.md)
- [Node Log PVC](../../configs/anomaly/log.pvc.yaml)

## 1. Repository Layout

The implementation is split into two layers.

The YAML assets are now flattened under [configs/anomaly](../../configs/anomaly).

The node scenarios can be identified by filename patterns:

- CPU: `cpu-payload-*.ramp*` and `cpu-payload-*.spike*`
- Memory: `mem-payload-*.high*` and `mem-payload-*.spike*`
- Network: `net-payload-*.delay*` and `net-payload-*.loss*`
- Disk: `disk-payload-*.fill*` and `disk-payload-*.burn*`

Each scenario still follows the same logical file set:

- `*-template*.yaml`: ChaosBlade CR manifest template with placeholders
- `*-env*.configmap.yaml`: default scenario parameters
- `*-script*.configmap.yaml`: `run.sh` mounted into the runner pod
- `*.job.yaml`: one-shot manual execution entry
- `*.cron.yaml`: scheduled execution entry
- `*_run.sh`: local convenience wrapper now flattened into `scripts/anomaly`

The operational shell entrypoints are now flattened under [scripts/anomaly](../../scripts/anomaly).

The shell filenames remain grouped by prefix:

- `node_cpu_*`
- `node_mem_*`
- `node_net_*`
- `node_disk_*`
- shared helpers such as `node_*_helper.sh`

This layer is what turns static YAML into a runnable workflow.

## 2. Execution Model

### 2.1 Runner Pod Pattern

Across all node scenarios, the CronJob and Job follow the same pattern:

- container image is usually `bitnami/kubectl:latest`
- `envFrom` loads parameters from the scenario env `ConfigMap`
- `/scripts` mounts the runner script `ConfigMap`
- `/payload` mounts the ChaosBlade template `ConfigMap`
- `/logs` mounts the shared PVC
- the entrypoint is `/scripts/run.sh`

Example:

- [cpu-payload.ramp.cron.yaml](../../configs/anomaly/cpu-payload.ramp.cron.yaml)

### 2.2 Helper Script Contract

Each node scenario has a dedicated helper script in [scripts/anomaly](../../scripts/anomaly), for example:

- [node_cpu_ramp_helper.sh](../../scripts/anomaly/node_cpu_ramp_helper.sh)
- [node_cpu_spike_helper.sh](../../scripts/anomaly/node_cpu_spike_helper.sh)
- [node_mem_high_helper.sh](../../scripts/anomaly/node_mem_high_helper.sh)
- [node_mem_spike_helper.sh](../../scripts/anomaly/node_mem_spike_helper.sh)
- [node_net_delay_helper.sh](../../scripts/anomaly/node_net_delay_helper.sh)
- [node_net_loss_helper.sh](../../scripts/anomaly/node_net_loss_helper.sh)
- [node_disk_fill_helper.sh](../../scripts/anomaly/node_disk_fill_helper.sh)
- [node_disk_burn_helper.sh](../../scripts/anomaly/node_disk_burn_helper.sh)

The helpers expose a stable command model:

- `install`: apply ConfigMaps
- `install job`: apply Job prerequisites only
- `install cron`: apply CronJob resources only
- `install all`: install the full scenario set
- `set KEY=VALUE`: patch the env `ConfigMap`
- `job run|logs|status|set`
- `cron enable|resume|suspend|schedule|set|status`
- `show`
- `stop`
- `uninstall`

### 2.3 Launcher Script Role

The scenario launchers in `scripts/anomaly` set a lab-ready default configuration and then call the helper.

Representative examples:

- [node_cpu_ramp_cron_run.sh](../../scripts/anomaly/node_cpu_ramp_cron_run.sh)
- [node_cpu_spike_cron_run.sh](../../scripts/anomaly/node_cpu_spike_cron_run.sh)
- [node_mem_high_cron_run.sh](../../scripts/anomaly/node_mem_high_cron_run.sh)
- [node_net_delay_cron_run.sh](../../scripts/anomaly/node_net_delay_cron_run.sh)
- [node_disk_fill_job_run.sh](../../scripts/anomaly/node_disk_fill_job_run.sh)

This means the checked-in CronJob YAML is only the baseline. The launchers usually patch runtime values after installation, especially:

- schedule
- activeDeadlineSeconds
- scenario-specific env values such as target node, percentages, hold windows, and paths

## 3. Shared Operational Behavior

The runner scripts in `configs/anomaly/*-script*.configmap.yaml` show several shared behaviors.

### 3.1 Log Output

Node jobs write both plain text logs and structured JSON logs into `/logs`, backed by:

- [log.pvc.yaml](../../configs/anomaly/log.pvc.yaml)

Typical behavior:

- `LOG_DIR` defaults to `/logs`
- log filenames include scenario, target, blade name, and timestamp
- several scripts write a companion `.json` file that captures `kubectl apply/get` results

### 3.2 Cleanup Model

The common model is:

- delete any stale ChaosBlade CR with the same `BLADE_NAME`
- create or apply a new CR rendered from the template
- wait for `status.phase=Running`
- hold for the requested duration
- delete the CR in a trap-based cleanup
- rely on `ttlSecondsAfterFinished` to remove finished Jobs and Pods

### 3.3 ConfigMap Overwrite Protection

Many helper scripts use `ENV_OVERWRITE=false` by default. If the env `ConfigMap` already exists, the helper skips re-applying the original env YAML so that patched runtime values are not overwritten.

That is an important design choice because the intended workflow is:

1. apply base ConfigMaps once
2. patch runtime values with `helper.sh set ...`
3. run Job or CronJob without losing local parameter changes

## 4. Scenario Matrix

### 4.1 CPU

Node CPU injection is implemented in:

- [Node YAML Assets](../../configs/anomaly)
- [Node Shell Assets](../../scripts/anomaly)

Important files:

- [cpu-payload-template.ramp.yaml](../../configs/anomaly/cpu-payload-template.ramp.yaml)
- [cpu-payload-script.ramp.configmap.yaml](../../configs/anomaly/cpu-payload-script.ramp.configmap.yaml)
- [cpu-payload-template.spike.yaml](../../configs/anomaly/cpu-payload-template.spike.yaml)
- [cpu-payload-script.spike.configmap.yaml](../../configs/anomaly/cpu-payload-script.spike.configmap.yaml)

Implementation notes:

- ramp mode repeatedly alternates between `HIGH` and `LOW`
- spike mode drives a single surge toward `SPIKE_PERCENT`
- both support `CPU_COUNT` or `CPU_LIST`, but not both at the same time
- launchers patch schedules after installation rather than relying only on the raw Cron YAML

Observed launcher defaults:

- Cron launchers commonly use `TARGET_NODE="emanage1"`
- Cron schedules are commonly patched to `30 */4 * * *`
- job launchers use more aggressive one-off values such as `HIGH=100`, `LOW=90`, or `SPIKE_PERCENT=100`

### 4.2 Memory

Node memory injection is implemented in:

- [Node YAML Assets](../../configs/anomaly)
- [Node Shell Assets](../../scripts/anomaly)

Important files:

- [mem-payload-template.high.yaml](../../configs/anomaly/mem-payload-template.high.yaml)
- [mem-payload-script.high.configmap.yaml](../../configs/anomaly/mem-payload-script.high.configmap.yaml)
- [mem-payload-template.spike.yaml](../../configs/anomaly/mem-payload-template.spike.yaml)
- [mem-payload-script.spike.configmap.yaml](../../configs/anomaly/mem-payload-script.spike.configmap.yaml)

Implementation notes:

- `PERCENT` is clamped by `MAX_MEM_PERCENT`
- `MEM_MODE` distinguishes RAM-style and cache-style behavior
- the high-memory script reads node capacity and derives a rate when possible
- several scripts allow explicit `TIMEOUT` override, otherwise compute timeout from ramp, hold, and padding

Observed launcher defaults:

- cron launchers commonly patch `PERCENT=85`, `MAX_MEM_PERCENT=90`
- cron schedules are commonly patched to `30 */4 * * *`
- one-off jobs target specific nodes such as `node3` or `master2`

### 4.3 Network

Node network injection is implemented in:

- [Node YAML Assets](../../configs/anomaly)
- [Node Shell Assets](../../scripts/anomaly)

Important files:

- [net-payload-template.delay.yaml](../../configs/anomaly/net-payload-template.delay.yaml)
- [net-payload-script.delay.configmap.yaml](../../configs/anomaly/net-payload-script.delay.configmap.yaml)
- [net-payload-template.loss.yaml](../../configs/anomaly/net-payload-template.loss.yaml)
- [net-payload-script.loss.configmap.yaml](../../configs/anomaly/net-payload-script.loss.configmap.yaml)

Implementation notes:

- delay mode uses `TIME_MS` and `OFFSET_MS`
- loss mode uses `PERCENT`
- optional matchers include local port, remote port, destination IP, exclude IP, and exclude port
- the scripts remove matcher blocks entirely when a value is unset or set to `-`
- the source note explicitly advises avoiding the node hosting the Prometheus Agent

Observed launcher defaults:

- Cron launchers commonly patch `TARGET_NODE="emanage1"`
- delay defaults are around `150ms +/- 50ms`
- loss defaults are around `10%`
- cron schedules are commonly patched to `30 */4 * * *`

### 4.4 Disk

Node disk injection is implemented in:

- [Node YAML Assets](../../configs/anomaly)
- [Node Shell Assets](../../scripts/anomaly)

Important files:

- [disk-payload-template.fill.yaml](../../configs/anomaly/disk-payload-template.fill.yaml)
- [disk-payload-script.fill.configmap.yaml](../../configs/anomaly/disk-payload-script.fill.configmap.yaml)
- [disk-payload-template.burn.yaml](../../configs/anomaly/disk-payload-template.burn.yaml)
- [disk-payload-script.burn.configmap.yaml](../../configs/anomaly/disk-payload-script.burn.configmap.yaml)

Implementation notes:

- fill mode enforces that exactly one of `PERCENT`, `RESERVE_MB`, or `SIZE_MB` is set
- fill mode optionally keeps a retained handle via `RETAIN_HANDLE`
- burn mode applies read and or write I/O pressure to a target path
- both scenarios compute hold and timeout windows and then remove the blade during cleanup
- the source note warns that fill mode can trigger pod eviction on important nodes

Observed launcher defaults:

- fill job launchers commonly target `/var/lib/rancher`
- fill examples use `PERCENT=90`
- burn examples usually set `READ=true`, `WRITE=true`, and `SIZE` around `20`
