# ChaosBlade Pod Injection

> **This procedure is suitable for a lab or controlled internal environment. <span style="color:red;">It is not written as a hardened production baseline.</span>**

## Overview

The pod injection implementation covers five major fault domains:

- container CPU stress
- container memory stress
- pod network delay and packet loss
- pod disk I/O delay and error injection
- pod self-resource failure and deletion

Unlike the earlier note-only summary, the repository already contains a fairly complete implementation. The technical design is therefore best understood as a layered runtime framework:

- scenario YAML assets under `configs/anomaly`
- helper scripts under `scripts/anomaly`
- launcher scripts under `scripts/anomaly`

Primary sources:

- [Pod YAML Assets](../../configs/anomaly)
- [Pod Shell Assets](../../scripts/anomaly)
- [ChaosBlade Install](../install/21-Chaosblade-Install.md)

## 1. Repository Layout

### 1.1 YAML Layer

The implementation assets are now flattened under [configs/anomaly](../../configs/anomaly).

The pod scenarios can be identified by filename patterns:

- CPU: `cpu-payload*.pod.ramp*` and `cpu-payload*.pod.spike*`
- Memory: `mem-payload*.pod.high*` and `mem-payload*.pod.spike*`
- Network: `net-payload*.pod.delay*` and `net-payload*.pod.loss*`
- Disk delay and error: `disk-io-payload*.pod.*`
- Self-resource: `pod-payload*.pod.delete*` and `pod-payload*.pod.fail*`

Each scenario still keeps the same logical resource set:

- template YAML
- env `ConfigMap`
- script `ConfigMap`
- manual `Job`
- scheduled `CronJob`
- scenario-local `run.sh` logic, now flattened into `scripts/anomaly` as `*_run.sh`

### 1.2 Shell Layer

The operational layer is now flattened under [scripts/anomaly](../../scripts/anomaly).

The shell filenames are grouped by prefix:

- `pod_cpu_*`
- `pod_mem_*`
- `pod_net_*`
- `pod_disk_*`
- `pod_self_resource_*`
- helper scripts such as `pod_*_helper.sh`

As with node injection, the helper scripts provide the real operational entrypoint.

## 2. Shared Execution Pattern

### 2.1 Runner Pod Structure

The pod scenarios use the same runner design as the node scenarios:

- `bitnami/kubectl:latest` is used as the runner image
- env parameters are injected via `envFrom`
- `/scripts` mounts the script `ConfigMap`
- `/payload` mounts the template `ConfigMap`
- `/logs` mounts the shared PVC
- the runner executes `/scripts/run.sh`

Example:

- [pod-payload.pod.delete.cron.yaml](../../configs/anomaly/pod-payload.pod.delete.cron.yaml)

### 2.2 Helper Script Contract

Each pod scenario has a helper in [scripts/anomaly](../../scripts/anomaly), for example:

- [pod_cpu_ramp_helper.sh](../../scripts/anomaly/pod_cpu_ramp_helper.sh)
- [pod_cpu_spike_helper.sh](../../scripts/anomaly/pod_cpu_spike_helper.sh)
- [pod_mem_high_helper.sh](../../scripts/anomaly/pod_mem_high_helper.sh)
- [pod_mem_spike_helper.sh](../../scripts/anomaly/pod_mem_spike_helper.sh)
- [pod_net_delay_helper.sh](../../scripts/anomaly/pod_net_delay_helper.sh)
- [pod_net_loss_helper.sh](../../scripts/anomaly/pod_net_loss_helper.sh)
- [pod_disk_io_delay_stable_helper.sh](../../scripts/anomaly/pod_disk_io_delay_stable_helper.sh)
- [pod_disk_io_delay_intermit_helper.sh](../../scripts/anomaly/pod_disk_io_delay_intermit_helper.sh)
- [pod_disk_io_error_fixed_helper.sh](../../scripts/anomaly/pod_disk_io_error_fixed_helper.sh)
- [pod_disk_io_error_intermit_helper.sh](../../scripts/anomaly/pod_disk_io_error_intermit_helper.sh)
- [pod_self_resource_delete_helper.sh](../../scripts/anomaly/pod_self_resource_delete_helper.sh)
- [pod_self_resource_fail_helper.sh](../../scripts/anomaly/pod_self_resource_fail_helper.sh)

The interface is intentionally uniform:

- `install`
- `install job`
- `install cron`
- `install all`
- `set KEY=VALUE`
- `job run|logs|status|set`
- `cron enable|resume|suspend|schedule|set|status`
- `show`
- `stop`
- `uninstall`

### 2.3 Pod Selection Strategy

Pod scenarios support more than one target-resolution mode.

Depending on the helper and launcher, the target can be resolved by:

- explicit `TARGET_NS` plus `POD_NAME`
- label-based selection via `POD_LABELS`
- higher-level helper options such as `SELECTOR` and `SELECTOR_MODE`
- runtime resolution of the newest running pod from a label selector

This is visible in launchers such as:

- [pod_cpu_spike_cron_run.sh](../../scripts/anomaly/pod_cpu_spike_cron_run.sh)
- [pod_net_delay_cron_run.sh](../../scripts/anomaly/pod_net_delay_cron_run.sh)
- [pod_self_resource_delete_cron_run.sh](../../scripts/anomaly/pod_self_resource_delete_cron_run.sh)

Operationally, the repository prefers dynamic pod resolution for CronJobs, so scheduled runs keep following the current pod instance instead of a stale name.

## 3. Shared Runtime Behavior

Pod runners write into `/logs` and usually emit:

- a plain `.log` file for human-readable execution traces
- a `.json` file containing `kubectl apply/get` outputs

The scripts generally:

- validate that the target pod exists
- validate the target container when container-level injection is required
- delete a stale ChaosBlade CR with the same `BLADE_NAME`
- render the final manifest from `/payload`
- drop optional matchers when parameters are empty or `-`
- apply the manifest
- wait until the blade reaches `Running`
- hold for a fixed or random duration
- delete the blade during cleanup

As with node injection, many pod helpers default to `ENV_OVERWRITE=false`. This avoids overwriting previously patched env `ConfigMap` values when the scenario is reinstalled.

Several pod scripts already detect whether `chaosblades.chaosblade.io` is cluster-scoped or namespaced and then choose the correct `kubectl` invocation. That is visible in scripts such as:

- [net-payload-script.pod.delay.configmap.yaml](../../configs/anomaly/net-payload-script.pod.delay.configmap.yaml)
- [mem-payload-script.pod.high.configmap.yaml](../../configs/anomaly/mem-payload-script.pod.high.configmap.yaml)

The pod implementation is therefore more scope-aware than some older node scripts.

## 4. Scenario Matrix

### 4.1 Pod CPU

Implementation:

- [Pod YAML Assets](../../configs/anomaly)
- [Pod Shell Assets](../../scripts/anomaly)

Important files:

- [cpu-payload-script.pod.ramp.configmap.yaml](../../configs/anomaly/cpu-payload-script.pod.ramp.configmap.yaml)
- [cpu-payload-script.pod.spike.configmap.yaml](../../configs/anomaly/cpu-payload-script.pod.spike.configmap.yaml)
- [pod_cpu_ramp_cron_run.sh](../../scripts/anomaly/pod_cpu_ramp_cron_run.sh)
- [pod_cpu_spike_cron_run.sh](../../scripts/anomaly/pod_cpu_spike_cron_run.sh)

Behavior:

- injection is container-scoped, not node-scoped
- `TARGET_NS`, `POD_NAME`, and `CONTAINER_NAME` are required by the runner scripts
- optional `CPU_COUNT` and `CPU_LIST` matchers are supported but mutually exclusive
- `CGROUP_ROOT` is exposed because pod CPU injection depends on container cgroup resolution

Observed defaults:

- stress-test cron examples use `TARGET_NS="default"` and `POD_LABELS="app=stress-test"`
- application-specific job examples target real services such as `gitea` and `zot`
- pod CPU ramp cron is often patched to `30 */4 * * *`
- pod CPU spike cron examples also exist with `*/20 * * * *`

### 4.2 Pod Memory

Implementation:

- [Pod YAML Assets](../../configs/anomaly)
- [Pod Shell Assets](../../scripts/anomaly)

Important files:

- [mem-payload-script.pod.high.configmap.yaml](../../configs/anomaly/mem-payload-script.pod.high.configmap.yaml)
- [mem-payload-script.pod.spike.configmap.yaml](../../configs/anomaly/mem-payload-script.pod.spike.configmap.yaml)
- [pod_mem_high_cron_run.sh](../../scripts/anomaly/pod_mem_high_cron_run.sh)
- [pod_mem_spike_cron_run.sh](../../scripts/anomaly/pod_mem_spike_cron_run.sh)

Behavior:

- memory injection is container-scoped
- the runner validates the pod and container, and can fall back to the first container in some scripts
- `PERCENT` and `RESERVE_MB` are mutually exclusive high-memory controls
- `MAX_MEM_PERCENT` acts as a clamp
- `MEM_MODE`, `MEM_RATE`, and `CGROUP_ROOT` are exposed
- timeout is often derived from `RAMP_SECONDS + HOLD + TIMEOUT_PADDING`, but several scripts also allow explicit `TIMEOUT`

Observed defaults:

- cron examples often use `PERCENT=85` and `MAX_MEM_PERCENT=90`
- job examples target workloads such as `database`, `wiki`, and other service namespaces
- pod memory cron jobs commonly use `0 * * * *`

### 4.3 Pod Network

Implementation:

- [Pod YAML Assets](../../configs/anomaly)
- [Pod Shell Assets](../../scripts/anomaly)

Important files:

- [net-payload-script.pod.delay.configmap.yaml](../../configs/anomaly/net-payload-script.pod.delay.configmap.yaml)
- [net-payload-script.pod.loss.configmap.yaml](../../configs/anomaly/net-payload-script.pod.loss.configmap.yaml)
- [pod_net_delay_cron_run.sh](../../scripts/anomaly/pod_net_delay_cron_run.sh)
- [pod_net_loss_cron_run.sh](../../scripts/anomaly/pod_net_loss_cron_run.sh)

Behavior:

- delay mode uses `DELAY_TIME_MS` and `DELAY_OFFSET_MS`
- loss mode uses `LOSS_PERCENT`
- optional traffic selection uses local port, remote port, destination IP, exclude IP, exclude port, and interface
- several scenarios support `EVICT_COUNT`, `EVICT_PERCENT`, and `WAITING_TIME` in addition to the net fault itself
- scripts dynamically remove matcher blocks when options are unset

Observed defaults:

- cron examples usually target `default` plus `app=stress-test`
- job examples include application namespaces such as `gitea`
- common delay defaults are around `150ms`
- common loss defaults are around `30%`
- pod network cron schedules usually use `0 * * * *`

### 4.4 Pod Disk I/O

Implementation:

- Delay stable:
  [disk-io-payload-template.pod.delay.stable.yaml](../../configs/anomaly/disk-io-payload-template.pod.delay.stable.yaml)
- Delay intermit:
  [disk-io-payload-template.pod.delay.intermit.yaml](../../configs/anomaly/disk-io-payload-template.pod.delay.intermit.yaml)
- Error fixed:
  [disk-io-payload-template.pod.error.fixed.yaml](../../configs/anomaly/disk-io-payload-template.pod.error.fixed.yaml)
- Error intermit:
  [disk-io-payload-template.pod.error.intermit.yaml](../../configs/anomaly/disk-io-payload-template.pod.error.intermit.yaml)
- Launchers:
  [Pod Shell Assets](../../scripts/anomaly)

Important files:

- [disk-io-payload-script.pod.delay.stable.configmap.yaml](../../configs/anomaly/disk-io-payload-script.pod.delay.stable.configmap.yaml)
- [disk-io-payload-script.pod.delay.intermit.configmap.yaml](../../configs/anomaly/disk-io-payload-script.pod.delay.intermit.configmap.yaml)
- [disk-io-payload-script.pod.error.fixed.configmap.yaml](../../configs/anomaly/disk-io-payload-script.pod.error.fixed.configmap.yaml)
- [disk-io-payload-script.pod.error.intermit.configmap.yaml](../../configs/anomaly/disk-io-payload-script.pod.error.intermit.configmap.yaml)

Behavior:

- delay scenarios use `IO_METHOD`, `IO_DELAY_MS`, `IO_PERCENT`, and `IO_PATH`
- error scenarios use `IO_METHOD`, `IO_ERRNO`, `IO_PERCENT`, and `IO_PATH`
- intermit scenarios alternate between fault and recovery windows
- `EVICT_COUNT`, `EVICT_PERCENT`, and `WAITING_TIME` are available in several pod disk scenarios
- the intermit error script can optionally generate synthetic I/O traffic with `IO_GEN_ENABLE`, `IO_GEN_MODE`, and related settings so the fault is observable
- the runner checks for the `chaosblade-fuse` sidecar because pod I/O fault injection depends on the injected volume path

Observed defaults:

- stable delay examples use values such as `IO_METHOD=read`, `IO_DELAY_MS=1000`, `IO_PERCENT=100`
- fixed error examples use values such as `IO_ERRNO=5`
- cron schedules are commonly patched to `0 * * * *`

### 4.5 Pod Self-Resource Faults

Implementation:

- [Pod YAML Assets](../../configs/anomaly)
- [Pod Shell Assets](../../scripts/anomaly)

Important files:

- [pod-payload-script.pod.delete.configmap.yaml](../../configs/anomaly/pod-payload-script.pod.delete.configmap.yaml)
- [pod-payload-script.pod.fail.configmap.yaml](../../configs/anomaly/pod-payload-script.pod.fail.configmap.yaml)
- [pod_self_resource_delete_cron_run.sh](../../scripts/anomaly/pod_self_resource_delete_cron_run.sh)
- [pod_self_resource_fail_cron_run.sh](../../scripts/anomaly/pod_self_resource_fail_cron_run.sh)

Behavior:

- pod delete is modeled as a one-shot disappearance window
- pod fail is modeled as an unavailable state rather than a direct deletion
- both support `POD_NAME` or `POD_LABELS`
- `EVICT_COUNT` and `EVICT_PERCENT` are mutually exclusive
- delete scripts recommend disabling timeout in some one-shot cases
- fail scripts commonly enable timeout protection

Observed defaults:

- delete cron uses a short hold window, for example `60` to `120` seconds
- fail cron uses longer windows, for example `600` to `1200` seconds in the default stress-test profile
- cron schedule is commonly `0 * * * *`

## 5. Static YAML Versus Runtime Behavior

The raw YAML under `configs/anomaly` is not the whole story. The launchers actively reshape the runtime behavior by:

- resolving the current target pod dynamically
- patching env values into the scenario `ConfigMap`
- patching CronJob schedule, deadlines, and history limits
- enabling the CronJob only after the runtime state is prepared

This matters because:

- the YAML may contain a generic baseline schedule
- the launcher may patch a different schedule
- the final target pod may be the newest running pod rather than the literal value in the original env YAML

For pod scenarios, the shell workflow is therefore the authoritative execution path.
