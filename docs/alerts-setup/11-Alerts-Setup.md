# Alerts Setup

This document summarizes the alert YAML currently stored under `configs/pipelines/alerts-setup/`.

Source notes:

- `Node Exporter` keeps the normalized PrometheusRule fragments that were already present under `TEMP/*.yaml`.
- `Kubernetes Control Plane` is now constrained to metrics that come from `monitor-kube-prometheus-stack-values.yaml`, specifically the aggregated series under `additionalPrometheusRulesMap`.
- `Container And Pod`, `kube-state-metrics`, and `CoreDNS` still follow the TEMP alert-design notes plus the generated alert YAML already committed in this repo; they have not yet been rewritten to a strict `additionalPrometheusRulesMap`-only source policy.

Related documents:

- [10-MetricsAggregate-Process.md](../metric_preprocess/10-MetricsAggregate-Process.md)
- [retained-metrics-overview.md](../../templates/markdown/retained-metrics-overview.md)

Split YAML references:

- [node-exporter.yaml](../../configs/pipelines/alerts-setup/node-exporter.yaml)
- [kube-apiservice.yaml](../../configs/pipelines/alerts-setup/kube-apiservice.yaml)
- [kube-apiserver.yaml](../../configs/pipelines/alerts-setup/kube-apiserver.yaml)
- [kube-controller-manager.yaml](../../configs/pipelines/alerts-setup/kube-controller-manager.yaml)
- [kube-scheduler.yaml](../../configs/pipelines/alerts-setup/kube-scheduler.yaml)
- [kubelet.yaml](../../configs/pipelines/alerts-setup/kubelet.yaml)
- [kube-proxy.yaml](../../configs/pipelines/alerts-setup/kube-proxy.yaml)
- [container-and-pod.yaml](../../configs/pipelines/alerts-setup/container-and-pod.yaml)
- [kube-state-metrics.yaml](../../configs/pipelines/alerts-setup/kube-state-metrics.yaml)
- [coredns.yaml](../../configs/pipelines/alerts-setup/coredns.yaml)

> These alert rules are intended for lab-scale validation only and have not been verified for effectiveness in a live production environment.

## Node Exporter

Most groups are direct normalizations of the original PrometheusRule YAMLs.

> [node-exporter.yaml](../../configs/pipelines/alerts-setup/node-exporter.yaml).

### 1. Time And Timex Alerts

- `NodeClockNotSynchronized`: Node clock not synchronized.

  > Expr: node_timex_sync_status == 0

- `NodeClockOffsetTooHigh`: Node clock offset too high (>0.5s).
  > Expr: (abs(node_timex_offset_seconds) > 0.5) and (node_timex_sync_status == 1)

### 2. VM Fault Alerts

- `NodeMajorPageFaultRateHigh`: Major page fault rate is high.

  > Expr: node_exporter:node_vmstat_pgmajfault_rate_5m > 5

- `NodeMajorPageFaultThrashing`: Major page fault thrashing suspected.
  > Expr: ( max by (cluster, job, instance) (node*exporter:node_vmstat_pgmajfault_rate_5m) * ( ( max by (cluster, job, instance) (node*exporter:node_vmstat_pgmajfault_rate_5m) / clamp_min(max by (cluster, job, instance) (node_exporter:node_vmstat_pgfault_rate_5m), 1e-6) ) > bool 0.2 ) * (max by (cluster, job, instance) (node_exporter:node_vmstat_pgfault_rate_5m) > bool 200) ) > 20

### 3. Stat Alerts

- `NodeIOBlockedPressureHigh`: I/O blocked pressure anomaly.

  > Expr: ( node_exporter:node_procs_blocked:avg_5m > 1 ) and ( node_exporter:node_procs_blocked:avg_5m > avg_over_time(node_exporter:node_procs_blocked:avg_5m[6h]) + 4 \* clamp_min(stddev_over_time(node_exporter:node_procs_blocked:avg_5m[6h]), 0.5) )

- `NodeSchedulerPressureHigh`: Scheduler / context-switch pressure anomaly.

  > Expr: ( node_exporter:node_context_switches_per_second:rate_5m > 2000 ) and ( node_exporter:node_context_switches_per_second:rate_5m > avg_over_time(node_exporter:node_context_switches_per_second:rate_5m[6h]) + 4 \* clamp_min(stddev_over_time(node_exporter:node_context_switches_per_second:rate_5m[6h]), 200) ) and ( resets(node_context_switches_total[15m]) == 0 )

### 4. Softnet Alerts

- `NodeSoftnetSqueezedHigh`: Softnet budget pressure high.

  > Expr: ( (node_exporter:node_softnet_processed_rate_5m > 300 and node_exporter:node_softnet_squeezed_ratio_5m > 0.001) or (node_exporter:node_softnet_processed_rate_5m > 50 and node_exporter:node_softnet_squeezed_ratio_5m > 0.01) )

- `NodeSoftnetBacklogDelayHigh`: Softnet backlog delay high.

  > Expr: ( (node_exporter:node_softnet_processed_rate_5m > 300 and node_exporter:node_softnet_backlog_delay_seconds_5m > 0.01) or (node_exporter:node_softnet_processed_rate_5m > 50 and node_exporter:node_softnet_backlog_delay_seconds_5m > 0.05) )

- `NodeSoftnetDropRatioHigh`: Softnet packet drop detected.
  > Expr: ( (node_exporter:node_softnet_processed_rate_5m > 300 and node_exporter:node_softnet_drop_ratio_5m > 0.0001) or (node_exporter:node_softnet_processed_rate_5m > 50 and node_exporter:node_softnet_drop_ratio_5m > 0.001) )

### 5. Schedstat Alerts

- `NodeSchedWaitShareAnomaly`: Scheduler wait-share anomaly.

  > Expr: (node_exporter:node_sched_wait_share_5m > 0.35) and ( node_exporter:node_sched_wait_share_5m > avg_over_time(node_exporter:node_sched_wait_share_5m[6h]) + 4 \* clamp_min(stddev_over_time(node_exporter:node_sched_wait_share_5m[6h]), 0.02) ) and ( sum without (cpu) (rate(node_schedstat_waiting_seconds_total[5m])) + sum without (cpu) (rate(node_schedstat_running_seconds_total[5m])) ) > 0.05

- `NodeSchedWaitShareCritical`: Scheduler wait-share critical.
  > Expr: (node_exporter:node_sched_wait_share_5m > 0.75) and ( sum without (cpu) (rate(node_schedstat_waiting_seconds_total[5m])) + sum without (cpu) (rate(node_schedstat_running_seconds_total[5m])) ) > 0.05

### 6. PSI Alerts

- `NodePressureCPUWaitHigh`: CPU pressure (wait) high.

  > Expr: node_exporter:node_pressure_cpu_wait_ratio_5m > 0.10

- `NodePressureIOWaitHigh`: IO pressure (wait) high.

  > Expr: node_exporter:node_pressure_io_wait_ratio_5m > 0.05

- `NodePressureMemWaitHigh`: Memory pressure (wait) high.
  > Expr: node_exporter:node_pressure_mem_wait_ratio_5m > 0.02

### 7. Netstat Alerts

- `NodeTcpReliabilityDegraded`: TCP reliability degraded.

  > Expr: node_exporter:node_net_tcp_retrans_timeout:rate5m > 2

- `NodeTcpListenDropsHigh`: TCP listen drops detected.
  > Expr: node_exporter:node_net_tcp_listen_drops:rate5m > 1

### 8. Netdev Alerts

- `NodeNetRxDropRatioHigh`: RX drop rate high.

  > Expr: node_exporter:node_net_rx_drop_ratio_ens33:rate5m > 0.001

- `NodeNetTxDropRatioHigh`: TX drop rate high.

  > Expr: node_exporter:node_net_tx_drop_ratio_ens33:rate5m > 0.001

- `NodeNetRxErrorRatioHigh`: RX error rate high.

  > Expr: node_exporter:node_net_rx_loss_error_ratio_ens33:rate5m > 0.0001

- `NodeNetTxErrorRatioHigh`: TX error rate high.
  > Expr: node_exporter:node_net_tx_loss_error_ratio_ens33:rate5m > 0.0001

### 9. Memory Alerts

- `NodeMemUtilizationHigh`: Memory utilization high above baseline.

  > Expr: ( node_exporter:node_mem_utilization_ratio > 0.90 ) and ( node_exporter:node_mem_utilization_ratio > avg_over_time(node_exporter:node_mem_utilization_ratio[6h] offset 5m) + 2 \* clamp_min(stddev_over_time(node_exporter:node_mem_utilization_ratio[6h] offset 5m), 0.03) )

- `NodeMemHeadroomLow`: Low available memory headroom.

  > Expr: node_exporter:node_mem_headroom_ratio < 0.10

- `NodeMemHeadroomSlopeHigh`: Available memory decreasing rapidly.

  > Expr: node_exporter:node_mem_headroom_slope_bytes_per_sec_5m < -1e7

- `NodeMemCacheRatioHigh`: High page cache ratio above baseline.

  > Expr: ( node_exporter:node_mem_cache_ratio > 0.70 ) and ( node_exporter:node_mem_cache_ratio > avg_over_time(node_exporter:node_mem_cache_ratio[6h] offset 5m) + 2 \* clamp_min(stddev_over_time(node_exporter:node_mem_cache_ratio[6h] offset 5m), 0.05) )

- `NodeMemAnonRatioHigh`: High anonymous memory ratio above baseline.

  > Expr: ( node_exporter:node_mem_anon_ratio > 0.60 ) and ( node_exporter:node_mem_anon_ratio > avg_over_time(node_exporter:node_mem_anon_ratio[6h] offset 5m) + 2 \* clamp_min(stddev_over_time(node_exporter:node_mem_anon_ratio[6h] offset 5m), 0.05) )

- `NodeMemDirtyWritebackRatioHigh`: High dirty/writeback ratio above baseline.

  > Expr: ( node_exporter:node_mem_dirty_writeback_ratio > 0.05 ) and ( node_exporter:node_mem_dirty_writeback_ratio > avg_over_time(node_exporter:node_mem_dirty_writeback_ratio[6h] offset 5m) + 2 \* clamp_min(stddev_over_time(node_exporter:node_mem_dirty_writeback_ratio[6h] offset 5m), 0.05) )

- `NodeMemKernelHardReclaimRatioHigh`: High kernel hard reclaim ratio.
  > Expr: node_exporter:node_mem_kernel_hard_reclaim_ratio > 0.20

### 10. Load Alerts

- `NodeLoadSustainedHigh`: Sustained high normalized load.

  > Expr: ( node_load15 / count without(cpu, mode) (node_cpu_seconds_total{mode="idle"}) ) > 1.0

- `NodeLoadSpiking`: Load spike above the long-window baseline.
  > Expr: ( ( node_load1 / count without(cpu, mode) (node_cpu_seconds_total{mode="idle"}) ) > 1.0 ) and (node_load1 > 1.5 \* node_load15)

### 11. Filesystem Alerts

- `NodeRootFSDeviceError`: Root FS device_error.

  > Expr: node_exporter:node_filesystem_root:device_error > 0

- `NodeRootFSReadOnly`: Root FS read-only.

  > Expr: node_exporter:node_filesystem_root:readonly > 0

- `NodeRootFSSpaceLow`: Root FS low space.

  > Expr: node_exporter:node_filesystem_root:avail_ratio < 0.10

- `NodeRootFSInodeLow`: Root FS low inodes.
  > Expr: node_exporter:node_filesystem_root:inode_free_ratio < 0.05

### 12. File Descriptor Alerts

- `NodeFileFDUtilizationHigh`: High file descriptor utilization.

  > Expr: node_exporter:node_filefd:utilization_ratio > 0.90

- `NodeFileFDAllocatedDeltaHigh`: File descriptor allocation increasing rapidly.
  > Expr: (node_exporter:node_filefd:allocated_delta_5m > 10000) and (node_exporter:node_filefd:utilization_ratio > 0.70)

### 13. Disk Alerts

- `NodeDiskUtilizationHigh`: Disk utilization high.

  > Expr: node_exporter:node_disk:utilization_max_5m > 0.90

- `NodeDiskQueueDepthHigh`: Disk queue depth high.

  > Expr: node_exporter:node_disk:queue_depth_max_5m > 2

- `NodeDiskReadLatencyHigh`: Disk read latency high.

  > Expr: node_exporter:node_disk:read_latency_avg_5m > 0.05

- `NodeDiskWriteLatencyHigh`: Disk write latency high.
  > Expr: node_exporter:node_disk:write_latency_avg_5m > 0.05

### 14. CPU Alerts

- `NodeCPUUtilHigh`: High CPU utilization.
  > Expr: node_exporter:node_cpu_util_ratio > 0.90

## Kubernetes Control Plane

Split YAML references:

- [kube-apiservice.yaml](../../configs/pipelines/alerts-setup/kube-apiservice.yaml)
- [kube-apiserver.yaml](../../configs/pipelines/alerts-setup/kube-apiserver.yaml)
- [kube-controller-manager.yaml](../../configs/pipelines/alerts-setup/kube-controller-manager.yaml)
- [kube-scheduler.yaml](../../configs/pipelines/alerts-setup/kube-scheduler.yaml)
- [kubelet.yaml](../../configs/pipelines/alerts-setup/kubelet.yaml)
- [kube-proxy.yaml](../../configs/pipelines/alerts-setup/kube-proxy.yaml)

### 1. APIService Alerts

This template is built from [kube-apiserver.yaml](../../configs/pipelines/metric-aggregate/kube-apiserver.yaml).

- `APIServiceUnavailable`: An aggregated APIService is unavailable.
  > Expr: kube:apiservice:unavailable:max > 0

### 2. API Server Alerts

This template is built from [kube-apiserver.yaml](../../configs/pipelines/metric-aggregate/kube-apiserver.yaml).

- `APIServerAdmissionRejectRatioHigh`: kube-apiserver admission rejection ratio is high.

  > Expr: kube:apiserver:admission_controller:rejected:ratio5m > 0.05

- `APIServerAdmissionWebhookErrorRatioHigh`: kube-apiserver admission webhook error ratio is high.

  > Expr: kube:apiserver:admission_controller:admission_webhook_error_ratio:ratio5m > 0.05

- `APIServerAuthenticationFailureRatioHigh`: kube-apiserver authentication failures are elevated.

  > Expr: kube:apiserver:authentication:attempts_fail_ratio:ratio5m > 0.05

- `APIServerTokenRequestStaleTokensHigh`: kube-apiserver issues stale service-account tokens.

  > Expr: kube:apiserver:serviceaccount:tokenrequest_stale_tokens:rate5m > 0

- `APIServerInflightRequestsHigh`: kube-apiserver inflight request load is high.

  > Expr: kube:apiserver:requests:inflight:max5m > 200

- `APIServerServerErrorRatioHigh`: kube-apiserver 5xx ratio is high.

  > Expr: kube:apiserver:requests:server_error_ratio:ratio5m > 0.01

- `APIServerRequestLatencyHigh`: kube-apiserver request latency is high.

  > Expr: kube:apiserver:requests:duration:avg5m > 1

- `APIServerAPFQueueingHigh`: kube-apiserver APF queueing is high.

  > Expr: kube:apiserver:apf:inqueue_seats:max5m > 10

- `APIServerAPFSeatUtilizationHigh`: kube-apiserver APF seat utilization is high.

  > Expr: kube:apiserver:apf:seat_utilization:avg5m > 0.9

- `APIServerWatchCacheFallbackHigh`: kube-apiserver watch-cache fallback ratio is high.

  > Expr: kube:apiserver:watchcache:consistent_read_fallback_ratio:ratio5m > 0.05

- `APIServerTokenCacheMissRatioHigh`: kube-apiserver token-cache miss ratio is high.

  > Expr: kube:apiserver:authn:token_cache:miss_ratio:ratio5m > 0.5

- `APIServerAuditRequestsRejected`: kube-apiserver rejects audit requests.

  > Expr: kube:apiserver:audit:requests_rejected:rate5m > 0

- `APIServerServiceRepairErrors`: kube-apiserver service repair reports reconcile errors.
  > Expr: kube:apiserver:service_repair:reconcile_errors:rate5m > 0

### 3. Controller Manager Alerts

This template is built from [kube-controller-manager.yaml](../../configs/pipelines/metric-aggregate/kube-controller-manager.yaml).

- `KubeControllerManagerEndpointSliceSyncFailures`: kube-controller-manager EndpointSlice sync failures continue.

  > Expr: kube:controller_manager:endpointslice:sync_failures:rate5m > 0

- `KubeControllerManagerEndpointSliceDriftHigh`: kube-controller-manager EndpointSlice actual-to-desired ratio drifts.

  > Expr: abs(kube:controller_manager:endpointslice:slices_actual_to_desired:ratio5m - 1) > 0.2

- `KubeControllerManagerEndpointSliceMirroringDriftHigh`: kube-controller-manager mirrored EndpointSlice ratio drifts.

  > Expr: abs(kube:controller_manager:endpointslice_mirroring:slices_actual_to_desired:ratio5m - 1) > 0.2

- `KubeControllerManagerServiceNodeSyncErrors`: kube-controller-manager service node-sync errors occur.

  > Expr: kube:service_controller:nodesync_error:rate5m > 0

- `KubeControllerManagerUnhealthyNodesRatioHigh`: kube-controller-manager sees too many unhealthy nodes.

  > Expr: kube:node_collector:unhealthy_nodes:ratio > 0.05

- `KubeControllerManagerCIDRRemainingLow`: kube-controller-manager CIDR headroom is low.

  > Expr: kube:node_ipam:cidrset_usage_cidrs:remaining < 0.1

- `KubeControllerManagerEphemeralVolumeCreateFailuresHigh`: kube-controller-manager ephemeral volume create failure ratio is high.

  > Expr: kube:storage:ephemeral_volume_controller:create_failures:ratio5m > 0.05

- `KubeControllerManagerCronJobCreationSkewHigh`: kube-controller-manager CronJob creation skew is high.

  > Expr: kube:cronjob_controller:job_creation_skew_seconds:avg5m > 60

- `KubeControllerManagerTaintEvictionsHigh`: kube-controller-manager taint evictions are happening.

  > Expr: kube:taint_eviction_controller:pod_deletions_total:rate5m > 0

- `KubeControllerManagerGarbageCollectorSyncErrors`: kube-controller-manager garbage collector reports sync errors.

  > Expr: kube:garbagecollector:resources_sync_error_total:rate5m > 0

- `KubeControllerManagerRootCASyncErrorsHigh`: kube-controller-manager root CA sync error ratio is high.

  > Expr: kube:root_ca_cert_publisher:sync_errors:ratio5m > 0.05

- `KubeControllerManagerManagedControllerDown`: A managed kube-controller-manager controller is not running.
  > Expr: kube:controller_manager:running_managed_controllers:up == 0

### 4. Scheduler Alerts

This template is built from [kube-scheduler.yaml](../../configs/pipelines/metric-aggregate/kube-scheduler.yaml).

- `KubeSchedulerPendingPodsHigh`: Scheduler pending pod backlog is high.

  > Expr: kube:scheduler:pending_pods:total > 20

- `KubeSchedulerSchedulingAttemptsHigh`: Scheduler needs many attempts per pod.

  > Expr: kube:scheduler:pod_scheduling_attempts:avg5m > 2

- `KubeSchedulerAssumedPodsCacheHigh`: Scheduler assumed-pod cache is high.

  > Expr: kube:scheduler:cache_size:assumed_pods > 100

- `KubeSchedulerAlgorithmLatencyHigh`: Scheduler algorithm latency is high.
  > Expr: kube:scheduler:scheduling_algorithm_duration_seconds:avg5m > 0.1

### 5. Kubelet Alerts

This template is built from [kubelet.yaml](../../configs/pipelines/metric-aggregate/kubelet.yaml).

- `KubeletHTTPInflightHigh`: kubelet inflight HTTP requests are high.

  > Expr: kube:kubelet:http_inflight:total > 200

- `KubeletHTTPEffectiveServiceTimeHigh`: kubelet effective HTTP service time is high.

  > Expr: kube:kubelet:http_effective_service_time_seconds:est5m > 1

- `KubeletStorageOpLatencyHigh`: kubelet storage operation latency is high.

  > Expr: kube:kubelet:storage_op:latency_seconds:avg5m > 1

- `KubeletStorageOpErrorRatioHigh`: kubelet storage operation error ratio is high.

  > Expr: kube:kubelet:storage_op:error_ratio:5m > 0.05

- `PVCUsedRatioHigh`: A PVC is almost full.

  > Expr: kube:pvc:used_ratio > 0.9

- `PVAbnormalCountHigh`: Abnormal persistent volumes exist.

  > Expr: kube:pv:abnormal:count > 0

- `KubeletPinningErrorRatioHigh`: kubelet pinning errors are occurring.

  > Expr: kube:kubelet:pinning_error_ratio:5m > 0

- `KubeletTopologyAdmissionErrorRatioHigh`: kubelet topology admission errors are occurring.

  > Expr: kube:kubelet:topology_admission_error_ratio:5m > 0

- `KubeletDockerOpsLatencyHigh`: kubelet docker operation latency is high.

  > Expr: kube:kubelet:docker_ops_latency_seconds:avg5m > 1

- `KubeletCNIOperationErrorRatioHigh`: kubelet CNI operation error ratio is high.

  > Expr: kube:kubelet:cni_ops_error_ratio:rate5m > 0.05

- `KubeletPodStartLatencyHigh`: kubelet pod-start latency is high.

  > Expr: kube:kubelet:pod_start_latency_seconds:avg5m > 30

- `KubeletPodStatusSyncLatencyHigh`: kubelet pod-status sync latency is high.

  > Expr: kube:kubelet:pod_status_sync_latency_seconds:avg5m > 5

- `KubeletPodStartErrorRatioHigh`: kubelet pod-start error ratio is high.

  > Expr: kube:kubelet:pod_start_error_ratio:rate5m > 0.05

- `KubeletDesiredWorkingPodsGapExists`: kubelet desired and working pod counts diverge.

  > Expr: kube:kubelet:pods_gap:desired_minus_working > 0

- `KubeletExitedContainerRatioHigh`: kubelet exited-container ratio is high.
  > Expr: kube:kubelet:containers_exited_ratio > 0.1

### 6. kube-proxy Alerts

This template is built from [kube-proxy.yaml](../../configs/pipelines/metric-aggregate/kube-proxy.yaml).

- `KubeProxyConntrackInvalidDropsHigh`: kube-proxy drops invalid conntrack-state packets.

  > Expr: kube:kubeproxy:ct_state_invalid_dropped_packets:rate5m > 0

- `KubeProxySyncRulesLatencyHigh`: kube-proxy full rule sync latency is high.
  > Expr: kube:kubeproxy:sync_full_proxy_rules_duration_seconds:avg5m > 1

## Container And Pod

### 1. CPU Alerts

- `PodCPUThrottlingHigh`: Pod CPU throttling ratio is high.

  > Expr: kube:pod_cpu_throttle_ratio:rate5m > 0.25

- `PodCPUUsageHighCores`: Pod CPU usage is sustained at a high core count.
  > Expr: kube:pod_cpu_cores:rate5m > 2

### 2. Memory Alerts

- `PodMemoryShareOfNodeTotalHigh`: A pod occupies a large share of its node memory.

  > Expr: kube:pod_mem_working_set_bytes / on(cluster, node) group_left(namespace, pod) clamp_min(node_memory_MemTotal_bytes{job="node-exporter"}, 1) > 0.30

- `PodMemoryWorkingSetGrowingFast`: Pod working set is growing rapidly.

  > Expr: kube:pod_mem_working_set_slope_bytes_per_sec:deriv5m > 1e7

- `PodMemoryRSSDominates`: Pod RSS dominates the working set.

  > Expr: (kube:pod_mem_rss_bytes / clamp_min(kube:pod_mem_working_set_bytes, 1) > 0.80) and (kube:pod_mem_working_set_bytes > 536870912)

- `PodMemoryCacheRatioHighUnderNodePressure`: Pod cache ratio stays high while node memory headroom is low.
  > Expr: (kube:pod_mem_cache_ratio > 0.60) and on(cluster, node) group_left(namespace, pod) (node_exporter:node_mem_headroom_ratio < 0.15)

### 3. Filesystem Alerts

- `PodFilesystemIOSustainedHigh`: Pod total filesystem IO is well above its baseline.

  > Expr: ( kube:pod_fs_bps:rate5m > 10485760 ) and ( kube:pod_fs_bps:rate5m > avg_over_time(kube:pod_fs_bps:rate5m[6h] offset 5m) + 3 \* clamp_min(stddev_over_time(kube:pod_fs_bps:rate5m[6h] offset 5m), 1048576) )

- `PodFilesystemWriteHigh`: Pod write throughput is well above its baseline.
  > Expr: ( kube:pod_fs_write_bps:rate5m > 5242880 ) and ( kube:pod_fs_write_bps:rate5m > avg_over_time(kube:pod_fs_write_bps:rate5m[6h] offset 5m) + 3 \* clamp_min(stddev_over_time(kube:pod_fs_write_bps:rate5m[6h] offset 5m), 524288) )

## kube-state-metrics

### 1. Node Health Alerts

- `NodeNotReady`: A node remains NotReady.

  > Expr: kube_state:node:not_ready > 0

- `NodeMemoryPressure`: A node reports MemoryPressure.

  > Expr: kube_state:node:memory_pressure > 0

- `NodeDiskPressure`: A node reports DiskPressure.

  > Expr: kube_state:node:disk_pressure > 0

- `NodePIDPressure`: A node reports PIDPressure.

  > Expr: kube_state:node:pid_pressure > 0

- `NodeUnschedulable`: A node remains unschedulable.
  > Expr: kube_state:node:unschedulable > 0

### 2. Pod Status Alerts

- `PodRestartsHigh`: A pod is restarting frequently.

  > Expr: sum by (cluster, namespace, pod) (increase(kube_pod_container_status_restarts_total[5m])) > 3

- `PodNotReadyExists`: A pod remains NotReady.

  > Expr: max by (cluster, namespace, pod) (1 - kube_pod_status_ready{condition="true"}) > 0

- `PodsWithWaitingContainers`: A pod contains waiting containers.

  > Expr: max by (cluster, namespace, pod) (kube_pod_container_status_waiting) > 0

- `PodReadyRatioLow`: Cluster pod readiness ratio is low.
  > Expr: kube_state:pod:pod_ready:ratio < 0.90

### 3. Deployment Alerts

- `DeploymentReplicasMissing`: A namespace is missing deployment replicas.

  > Expr: kube_state:deployment:deploy_replicas_missing:sum > 0

- `DeploymentAvailabilityLow`: Deployment availability ratio is low.
  > Expr: kube_state:deployment:deploy_availability:ratio < 0.90

### 4. Job Alerts

- `JobsFailedExists`: Failed jobs exist in the namespace.

  > Expr: kube_state:job:jobs_failed:count > 0

- `JobsRunningOver1hExists`: Long-running jobs exceed one hour.
  > Expr: kube_state:job:jobs_running_over_1h:count > 0

## CoreDNS

### 1. Cache Alerts

- `CoreDNSCacheRequestRateHigh`: CoreDNS cache request rate is far above baseline.

  > Expr: ( coredns:cache:req_rate5m > 1000 ) and ( coredns:cache:req_rate5m > avg_over_time(coredns:cache:req_rate5m[6h] offset 5m) + 3 \* clamp_min(stddev_over_time(coredns:cache:req_rate5m[6h] offset 5m), 50) )

- `CoreDNSCacheHitRatioLow`: CoreDNS cache hit ratio is low.

  > Expr: coredns:cache:hit_ratio5m < 0.40

- `CoreDNSCacheEntriesHigh`: CoreDNS cache entry count is unusually high.

  > Expr: coredns:cache:entries > 100000

- `CoreDNSCacheCounterResets`: CoreDNS cache counters reset unexpectedly.
  > Expr: coredns:cache:counter_resets5m > 0

### 2. DNS Request Alerts

- `CoreDNSRequestRateHigh`: CoreDNS request rate is far above baseline.

  > Expr: ( sum by (cluster, instance) (coredns:dns:req_rate5m) > 1000 ) and ( sum by (cluster, instance) (coredns:dns:req_rate5m) > avg_over_time(sum by (cluster, instance) (coredns:dns:req_rate5m)[6h] offset 5m) + 3 \* clamp_min(stddev_over_time(sum by (cluster, instance) (coredns:dns:req_rate5m)[6h] offset 5m), 50) )

- `CoreDNSRcodeErrorRatioHigh`: CoreDNS serves too many error responses.

  > Expr: coredns:dns:rcode_error_ratio5m > 0.05

- `CoreDNSLatencyHigh`: CoreDNS request latency is high.
  > Expr: coredns:dns:latency_avg_5m > 0.25

### 3. Forwarder Alerts

- `CoreDNSForwardHealthcheckBroken`: A CoreDNS upstream health check is failing.

  > Expr: coredns:forward:healthcheck_broken_rate5m > 0

- `CoreDNSForwardMaxConcurrentRejects`: CoreDNS is rejecting forward requests due to concurrency limits.

  > Expr: coredns:forward:max_concurrent_rejects_rate5m > 0

- `CoreDNSUpstreamLatencyHigh`: CoreDNS upstream latency is high.
  > Expr: coredns:forward:upstream_latency_avg_5m > 0.25

### 4. Health Alerts

- `CoreDNSHealthFailRate`: CoreDNS health checks are failing.
  > Expr: coredns:health:fail_rate5m > 0

### 5. Plugin Alerts

- `CoreDNSK3sAPIServerErrorRatioHigh`: CoreDNS Kubernetes plugin sees a high apiserver error ratio.

  > Expr: coredns:k3s:apiserver_error_ratio5m > 0.05

- `CoreDNSK3sAPIServerLatencyHigh`: CoreDNS Kubernetes plugin sees high apiserver latency.

  > Expr: coredns:k3s:apiserver_latency_avg5m > 0.25

- `CoreDNSK3sAPIServerRateLimiterWaitHigh`: CoreDNS spends too long waiting on its client-side rate limiter.

  > Expr: coredns:k3s:apiserver_rate_limiter_wait_avg5m > 0.05

- `CoreDNSCriticalEventsDetected`: CoreDNS reports reload failures or panics.
  > Expr: coredns:critical_events:rate5m > 0
