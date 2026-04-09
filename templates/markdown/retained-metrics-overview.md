# Retained Metrics Overview

> It covers only retained raw metrics. It does not cover recording rules, aggregation rules, `PrometheusRule` objects, or default rule disablement.

## Overview

This document explains which raw metrics are intentionally retained in the monitoring stack and why they are kept. The structure is organized in two layers:

- Monitoring component
- Metric type inside that component

The goal is not to reproduce every exporter metric page. The goal is to document the signals that the handwritten notes treated as operationally valuable after metric dropping.

This document should still be read together with the live configuration in [monitor-kube-prometheus-stack-values.yaml](../../configs/pipelines/prometheus_stack-install/monitor-kube-prometheus-stack-values.yaml), because the notes and the current deployed values may not always be identical.

## Alertmanager

### 1. Configuration Reload

Alertmanager keeps two configuration reload signals: `alertmanager_config_last_reload_successful` and `alertmanager_config_last_reload_success_timestamp_seconds`. Together they answer two basic questions: whether the last configuration reload succeeded, and when that last successful reload happened. They are kept because configuration drift and bad reloads are high-impact failures that are easy to miss if only notification counters are observed.

### 2. Notification Delivery

The retained notification metrics are `alertmanager_notifications_total` and `alertmanager_notifications_failed_total`. These are the compact, high-value signals for the outbound notification pipeline. The notes treat them as the minimum raw inputs needed to understand whether Alertmanager is actively trying to send notifications and whether those attempts are failing.

## cAdvisor

### 1. CPU Metrics

The retained cAdvisor CPU metrics are `container_cpu_usage_seconds_total`, `container_cpu_cfs_periods_total`, and `container_cpu_cfs_throttled_periods_total`. They are kept because they expose real container CPU consumption and CPU throttling pressure. This is the smallest useful set for identifying containers that are busy, containers that are quota-limited, and containers whose throttling ratio is increasing.

### 2. Memory Metrics

The retained cAdvisor memory metrics are `container_memory_working_set_bytes`, `container_memory_rss`, `container_memory_cache`, and `container_oom_events_total`. The notes keep them because they separate working set pressure from RSS and page cache, and because OOM events are directly actionable. In practice, these four metrics are enough to tell whether a container is truly memory-bound, cache-heavy, or already failing under memory pressure.

### 3. Filesystem Metrics

The retained filesystem throughput metrics are `container_fs_reads_bytes_total` and `container_fs_writes_bytes_total`. The handwritten notes treat them as the minimum raw indicators for container-level storage traffic. They help identify sustained read-heavy or write-heavy containers without carrying the full weight of inode, sector, merged IO, or filesystem metadata metrics.

### 4. Lifecycle And Scrape Health

The retained lifecycle and scrape-health metrics are `container_processes`, `container_threads`, and `container_scrape_error`. These are kept to answer whether a container is unexpectedly growing in process or thread count, and whether the cAdvisor scrape itself is unhealthy. The notes explicitly treat them as health and topology signals rather than resource-usage signals.

## CoreDNS

### 1. Cache Metrics

CoreDNS keeps `coredns_cache_entries`, `coredns_cache_hits_total`, and `coredns_cache_requests_total`. This set is enough to evaluate cache size and cache effectiveness without retaining lower-value miss-only detail. The notes consider cache behavior one of the most important DNS service quality signals because it directly affects upstream dependency pressure and end-to-end latency.

### 2. DNS Request Metrics

The retained request-path metrics are `coredns_dns_requests_total`, `coredns_dns_responses_total`, and `coredns_dns_request_duration_seconds`. These metrics describe request volume, response distribution, and latency. They are kept because they form the minimum raw picture of DNS traffic, error behavior, and request handling performance.

### 3. Forwarding And Upstream Dependency Metrics

The retained forward-path metrics are `coredns_forward_healthcheck_broken_total`, `coredns_forward_max_concurrent_rejects_total`, and `coredns_proxy_request_duration_seconds`. These were kept in the notes because they tell you whether CoreDNS is failing health checks against upstream resolvers, rejecting requests under concurrency pressure, or becoming slow when proxying upstream.

### 4. Kubernetes Plugin And Critical Event Metrics

The retained Kubernetes integration metrics are `coredns_kubernetes_rest_client_requests_total`, `coredns_kubernetes_rest_client_request_duration_seconds`, and `coredns_kubernetes_rest_client_rate_limiter_duration_seconds`. The retained self-event metrics are `coredns_health_request_failures_total`, `coredns_reload_failed_total`, and `coredns_panics_total`. These are kept because they surface two high-value failure domains: dependency quality against the apiserver and self-stability inside CoreDNS.

## kube-state-metrics

### 1. Node State Metrics

The retained node-state metrics are `kube_node_spec_unschedulable`, `kube_node_status_allocatable`, `kube_node_status_capacity`, and `kube_node_status_condition`. These are kept because they answer whether a node can schedule workloads, what capacity it advertises, what allocatable headroom it exposes, and whether it is under readiness, disk, memory, or PID pressure. We droped most node metadata, but they keep these state signals because they still matter for cluster health.

### 2. Pod And Container State Metrics

The retained pod and container state metrics are `kube_pod_container_status_restarts_total`, `kube_pod_container_status_ready`, `kube_pod_container_status_waiting`, and `kube_pod_status_ready`. These are the minimal raw signals needed to observe restart churn, readiness failures, and waiting containers. The notes intentionally drop most pod metadata but keep these state outcomes because they are directly relevant for workload troubleshooting.

### 3. Deployment Metrics

The retained Deployment metrics are `kube_deployment_spec_replicas` and `kube_deployment_status_replicas_available`. These are kept because they expose the simplest availability question for a Deployment: how many replicas are expected, and how many are actually available.

### 4. DaemonSet Metrics

The retained DaemonSet metrics are `kube_daemonset_status_desired_number_scheduled` and `kube_daemonset_status_number_ready`. They are kept for the same reason as the Deployment signals: they form the smallest possible readiness gap signal for host-wide agents and infrastructure DaemonSets.

### 5. Job Metrics

The retained Job metrics are `kube_job_status_start_time`, `kube_job_status_active`, and `kube_job_failed`. They are kept because they help identify three operationally important situations: long-running Jobs, currently active Jobs, and failed Jobs.

### 6. CronJob Metrics

The retained CronJob metrics are `kube_cronjob_status_last_schedule_time`, `kube_cronjob_status_last_successful_time`, and `kube_cronjob_status_active`. These are kept because they show whether a CronJob is still scheduling, whether it has been succeeding recently, and whether it currently has active runs.

## APIService

The retained `aggregator_unavailable_apiservice` metric is the compact signal for aggregated API availability. It tells you when an aggregated APIService is present but unavailable, which makes it useful for catching extension API outages that would otherwise look like generic control-plane failures from the caller side.

## kube-apiserver

### 1. Admission, Authentication, And Token Hygiene

The notes retain `apiserver_admission_controller_admission_duration_seconds`, `apiserver_admission_webhook_request_total`, `authentication_attempts`, and `serviceaccount_stale_tokens_total`. Together they cover the entry path of a request before it reaches business logic: how much admission work is happening, whether webhooks are failing, whether authentication is breaking down, and whether stale ServiceAccount tokens are still being used. They are kept because these are failure modes that quickly propagate into cluster-wide latency, rejection, and access problems.

### 2. Request Volume And Latency

The retained request-path metrics are `apiserver_current_inflight_requests`, `apiserver_current_inqueue_requests`, `apiserver_request_total`, `apiserver_request_sli_duration_seconds`, and `apiserver_request_duration_seconds`. This set is kept because it covers concurrency pressure, queue pressure, request throughput, and latency. Together they provide a compact raw view of whether the apiserver is busy, backlogged, or slow.

### 3. API Priority And Fairness

The retained APF metrics are `apiserver_flowcontrol_current_executing_seats`, `apiserver_flowcontrol_current_inqueue_seats`, `apiserver_flowcontrol_current_limit_seats`, `apiserver_flowcontrol_priority_level_seat_utilization`, `apiserver_flowcontrol_dispatched_requests_total`, and `apiserver_flowcontrol_request_concurrency_in_use`. These are kept because they expose how much concurrency is being consumed, how much work is queued, and whether APF is saturating.

### 4. Storage, Watch Cache, And Token Cache Signals

`apiserver_storage_list_total`, `apiserver_storage_size_bytes`, `apiserver_watch_cache_initializations_total`, `apiserver_watch_cache_consistent_read_total`, `apiserver_cache_list_total`, `authentication_token_cache_request_total`, and `authentication_token_cache_active_fetch_count` matter because they reveal whether the apiserver is putting unusual pressure on storage, rebuilding its watch cache too often, falling back to expensive consistent reads, relying heavily on cache-based list paths, or experiencing a high token-cache miss rate that forces frequent active fetches, all of which can be early signs of control-plane inefficiency, elevated latency, or instability.

### 5. Audit And Repair Signals

The retained audit and internal repair metrics are `apiserver_audit_event_total`, `apiserver_audit_requests_rejected_total`, `apiserver_clusterip_repair_reconcile_errors_total`, `apiserver_nodeport_repair_reconcile_errors_total`, and `apiserver_init_events_total`. They are kept because they surface hidden control-plane stress that may not appear in request latency alone: audit backpressure, reconciliation errors in Service repair loops, and repeated initialization activity.

## kube-controller-manager

### 1. Endpoint And Service Controller Signals

The retained EndpointSlice metrics are `endpoint_slice_controller_syncs`, `endpoint_slice_controller_num_endpoint_slices`, and `endpoint_slice_controller_desired_endpoint_slices`, together with the mirroring metrics `endpoint_slice_mirroring_controller_num_endpoint_slices` and `endpoint_slice_mirroring_controller_desired_endpoint_slices`. The notes also keep `service_controller_nodesync_error_total`. These metrics are retained because they show whether endpoint management is converging correctly and whether the Service controller is failing to synchronize node-related state.

### 2. Node, Storage, And Garbage-Collection Signals

The retained node and storage controller metrics are `node_authorizer_graph_actions_duration_seconds`, `node_collector_evictions_total`, `node_collector_unhealthy_nodes_in_zone`, `node_collector_zone_size`, `node_ipam_controller_cidrset_cidrs_allocations_total`, `node_ipam_controller_cidrset_usage_cidrs`, `node_ipam_controller_cirdset_max_cidrs`, `ephemeral_volume_controller_create_total`, `ephemeral_volume_controller_create_failures_total`, `cronjob_controller_job_creation_skew_duration_seconds`, and `garbagecollector_controller_resources_sync_error_total`. They are kept because they show whether node health remediation is active, whether CIDR space is being consumed, whether ephemeral volume creation is failing, whether CronJob-created Jobs are being scheduled late, and whether the garbage collector is falling out of sync with cluster resources.

### 3. Managed Controller Liveness

The retained `running_managed_controllers` metric is the direct liveness and inventory signal for controller-manager itself. The notes keep it because it shows which controllers are currently active and whether a manager instance has silently stopped running expected control loops.

## kube-scheduler

The retained scheduler metrics are `scheduler_pending_pods`, `scheduler_pod_scheduling_attempts`, `scheduler_scheduler_cache_size`, and `scheduler_scheduling_algorithm_duration_seconds`. They are kept because they answer four basic scheduling questions: how much work is waiting, how many retries a placement usually needs, how much assumed-pod state is sitting in the scheduler cache, and how expensive the core scheduling algorithm is becoming.

### kubelet

#### HTTP, Runtime, And Storage Signals

The retained kubelet transport, runtime, and storage metrics are `kubelet_http_inflight_requests`, `kubelet_http_requests_total`, `kubelet_docker_operations_total`, `kubelet_docker_operations_duration_seconds`, `storage_operation_duration_seconds`, `kubelet_volume_stats_capacity_bytes`, `kubelet_volume_stats_available_bytes`, and `kube_persistentvolume_status_phase`. These metrics are kept because they expose request pressure on kubelet itself, the volume-health view kubelet sees, and the cost or failure-proneness of runtime-facing operations that can slow pod startup or recovery.

#### CPU, Memory, And Topology Management Signals

The retained scheduler-resource-management signals are `kubelet_cpu_manager_pinning_requests_total`, `kubelet_cpu_manager_pinning_errors_total`, `kubelet_memory_manager_pinning_requests_total`, `kubelet_memory_manager_pinning_errors_total`, `kubelet_topology_manager_admission_requests_total`, and `kubelet_topology_manager_admission_errors_total`. They are kept because failures in these paths usually point to misalignment between workload requests and node topology.

#### Pod Lifecycle Signals

The retained lifecycle metrics are `kubelet_desired_pods`, `kubelet_active_pods`, `kubelet_running_pods`, `kubelet_running_containers`, `kubelet_working_pods`, `kubelet_network_plugin_operations_total`, `kubelet_network_plugin_operations_errors_total`, `kubelet_pod_start_duration_seconds`, `kubelet_pod_status_sync_duration_seconds`, `kubelet_started_pods_total`, and `kubelet_started_pods_errors_total`. The notes keep these because they are the raw inputs needed to understand kubelet workload scale, CNI failure rate, and pod start or sync efficiency.

### kube-proxy And kube-router

For kube-proxy, the retained raw metrics are `kubeproxy_iptables_ct_state_invalid_dropped_packets_total` and `kubeproxy_sync_full_proxy_rules_duration_seconds`. These are kept because they expose invalid conntrack drops and the cost of a full rule resync. The handwritten notes do discuss kube-router internals, but they do not treat kube-router metrics as part of the main retained signal set in the same way.

## node-exporter

### 1. Exporter Self-Observability

The retained exporter self-observability metrics are `go_gc_duration_seconds_sum`, `go_gc_duration_seconds_count`, `go_memstats_heap_inuse_bytes`, `go_memstats_heap_sys_bytes`, `go_memstats_alloc_bytes_total`, `go_goroutines`, `go_threads`, `process_cpu_seconds_total`, and `process_resident_memory_bytes`. These are kept because the notes still want a minimal ability to tell whether the exporter itself is healthy, leaking memory, or over-consuming CPU.

### 2. Time Synchronization

The retained time signals are `node_time_seconds`, `node_time_zone_offset_seconds`, `node_timex_offset_seconds`, and `node_timex_sync_status`. They are kept because time drift and NTP desynchronization are system-level risks that affect logging, scheduling, TLS, and alert correlation.

### 3. VM Pressure And Scheduler Pressure

The retained VM and pressure metrics are `node_vmstat_pgfault`, `node_vmstat_pgmajfault`, `node_softnet_dropped_total`, `node_softnet_times_squeezed_total`, `node_softnet_backlog_len`, `node_softnet_processed_total`, `node_schedstat_running_seconds_total`, `node_schedstat_waiting_seconds_total`, `node_pressure_cpu_waiting_seconds_total`, `node_pressure_io_waiting_seconds_total`, and `node_pressure_memory_waiting_seconds_total`. These are kept because they distinguish between normal system activity and pathological pressure: page faults, scheduling delays, packet backlog, and PSI saturation.

### 4. Network Health And Throughput

The retained network metrics are `node_netstat_Tcp_CurrEstab`, `node_netstat_Tcp_RetransSegs`, `node_netstat_TcpExt_TCPTimeouts`, `node_netstat_TcpExt_ListenDrops`, `node_netstat_Udp_InErrors`, `node_netstat_Udp_RcvbufErrors`, `node_network_receive_bytes_total`, `node_network_receive_packets_total`, `node_network_receive_drop_total`, `node_network_receive_errs_total`, `node_network_transmit_bytes_total`, `node_network_transmit_packets_total`, `node_network_transmit_drop_total`, and `node_network_transmit_errs_total`. Because they describe the minimum host-level network quality model: traffic, retransmission, queue pressure, drops, and receive or transmit errors.

### 5. Memory State

The retained node memory signals are `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes`, `node_memory_MemFree_bytes`, `node_memory_Buffers_bytes`, `node_memory_Cached_bytes`, `node_memory_Active_anon_bytes`, `node_memory_Inactive_anon_bytes`, `node_memory_Active_file_bytes`, `node_memory_Inactive_file_bytes`, `node_memory_Dirty_bytes`, `node_memory_Writeback_bytes`, `node_memory_AnonHugePages_bytes`, `node_memory_AnonPages_bytes`, `node_memory_Slab_bytes`, `node_memory_PageTables_bytes`, `node_memory_KernelStack_bytes`, `node_memory_SReclaimable_bytes`, `node_memory_Shmem_bytes`, `node_memory_Unevictable_bytes`, `node_memory_SUnreclaim_bytes`, `node_memory_Mlocked_bytes`, `node_memory_CommitLimit_bytes`, and `node_memory_Committed_AS_bytes`. These are retained because they let operators separate free memory, reclaimable cache, anonymous memory pressure, kernel overhead, and commit risk.

### 6. Filesystem, File Handle, Disk, And CPU State

The retained filesystem metrics are `node_filesystem_size_bytes`, `node_filesystem_avail_bytes`, `node_filesystem_files`, `node_filesystem_files_free`, `node_filesystem_readonly`, and `node_filesystem_device_error`. The retained file-handle metrics are `node_filefd_allocated` and `node_filefd_maximum`. The retained disk metrics are `node_disk_io_time_seconds_total`, `node_disk_io_time_weighted_seconds_total`, `node_disk_read_bytes_total`, `node_disk_written_bytes_total`, `node_disk_reads_completed_total`, `node_disk_writes_completed_total`, `node_disk_read_time_seconds_total`, and `node_disk_write_time_seconds_total`. The retained CPU metric is `node_cpu_seconds_total`. These are kept because they cover the basic host resource model: filesystem capacity, inode pressure, file descriptor exhaustion, disk utilization, disk queueing, throughput, latency, and CPU usage.

### 7. Host Load And Context Switch Activity

The reatained metrics are `node_context_switches_total`, `node_load1`, `node_load5`, and `node_load15`. They matter because they expose system churn and short-, medium-, and long-window load behavior, which often explain why a node feels busy even when a single resource metric looks normal.

## Prometheus

### 1. Readiness And Configuration State

The retained availability metrics are `prometheus_ready` and `prometheus_config_last_reload_successful`. These are kept because they answer whether Prometheus is serving and whether its last configuration reload succeeded.

### 2. Alert Delivery Pipeline

The retained notification-path metrics are `prometheus_notifications_queue_capacity`, `prometheus_notifications_queue_length`, `prometheus_notifications_errors_total`, `prometheus_notifications_sent_total`, and `prometheus_notifications_alertmanagers_discovered`. Because they are the minimum raw signals for queue saturation, delivery failure, and Alertmanager connectivity.

### 3. Remote Read And Remote Write

The retained remote-storage metrics are `prometheus_api_remote_write_invalid_labels_samples_total`, `prometheus_api_remote_write_without_metadata_appended_samples_total`, `prometheus_remote_read_handler_queries`, and `prometheus_remote_storage_samples_in_total`. These are kept because remote write problems usually surface first as invalid sample handling, metadata mismatch, or abnormal remote traffic volume.

### 4. Service Discovery And Scrape Execution

The retained discovery and scrape metrics are `prometheus_sd_discovered_targets`, `prometheus_sd_failed_configs`, `prometheus_sd_kubernetes_failures_total`, `prometheus_sd_updates_delayed_total`, and `scrape_duration_seconds`. These are kept because they show whether Prometheus can discover targets, whether Kubernetes-based SD is failing, whether updates are backing up, and whether scrape latency is rising.

## Prometheus Operator

### 1. Managed Resources

The retained resource-management metric is `prometheus_operator_managed_resources`. Because it is the only compact raw signal that shows whether a controller is selecting or rejecting monitored resources.

### 2. Kubernetes Client Behavior

The retained client-facing metric is `prometheus_operator_kubernetes_client_http_requests_total`, with success-heavy HTTP classes filtered out by the final metric drop rules. The point is not to keep every request. The point is to keep the failure-oriented remainder that still tells you when the Operator is having trouble talking to the Kubernetes API.

### 3. Sync, Reconcile, And Status Update Failures

The retained failure metrics are `prometheus_operator_list_operations_failed_total`, `prometheus_operator_node_syncs_failed_total`, `prometheus_operator_ready`, `prometheus_operator_reconcile_errors_total`, `prometheus_operator_status_update_errors_total`, and `prometheus_operator_syncs`. These are kept because they are the clearest raw signals for “Operator is unhealthy”, “Operator cannot reconcile correctly”, or “Operator cannot complete syncs”.

### 4. Watch And Workqueue Backlog

The retained watch and queue metrics are `prometheus_operator_watch_operations_total`, `prometheus_operator_watch_operations_failed_total`, `prometheus_operator_workqueue_adds_total`, `prometheus_operator_workqueue_depth`, `prometheus_operator_workqueue_unfinished_work_seconds`, `prometheus_operator_workqueue_longest_running_processor_seconds`, and `prometheus_operator_workqueue_retries_total`. These are kept because they reveal whether the Operator is falling behind, retrying too often, or failing to drain its controller queue.
