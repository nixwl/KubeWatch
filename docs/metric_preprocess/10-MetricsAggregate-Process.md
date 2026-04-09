# Metrics Aggregate Process

This document summarizes the recording rules defined under `additionalPrometheusRulesMap` in the live source of truth:

> [monitor-kube-prometheus-stack-values.yaml](../../configs/pipelines/prometheus_stack-install/monitor-kube-prometheus-stack-values.yaml)

Some rule names still reflect older experiments or contain typos. This document keeps the exact rule names that are currently deployed and explains the actual `expr` they run today.

Related documents:

- [retained-metrics-overview.md](../../templates/markdown/retained-metrics-overview.md)
- [09-MetricsDrop-Process.md](./09-MetricsDrop-Process.md)

Split YAML references:

- [node-exporter.yaml](../../configs/pipelines/metric-aggregate/node-exporter.yaml)
- [kube-apiserver.yaml](../../configs/pipelines/metric-aggregate/kube-apiserver.yaml)
- [kube-controller-manager.yaml](../../configs/pipelines/metric-aggregate/kube-controller-manager.yaml)
- [kube-scheduler.yaml](../../configs/pipelines/metric-aggregate/kube-scheduler.yaml)
- [kubelet.yaml](../../configs/pipelines/metric-aggregate/kubelet.yaml)
- [kube-proxy.yaml](../../configs/pipelines/metric-aggregate/kube-proxy.yaml)
- [container-and-pod.yaml](../../configs/pipelines/metric-aggregate/container-and-pod.yaml)
- [kube-state-metrics.yaml](../../configs/pipelines/metric-aggregate/kube-state-metrics.yaml)
- [alertmanager.yaml](../../configs/pipelines/metric-aggregate/alertmanager.yaml)
- [prometheus.yaml](../../configs/pipelines/metric-aggregate/prometheus.yaml)
- [prometheus-operator.yaml](../../configs/pipelines/metric-aggregate/prometheus-operator.yaml)
- [coredns.yaml](../../configs/pipelines/metric-aggregate/coredns.yaml)

## Node Exporter Metrics

These rules condense host metrics into node-level pressure, CPU, memory, disk, filesystem, and network signals. The current values file intentionally hard-codes some environment assumptions such as `ens33`, `^sd[a-z]+$`, and the root mount `/`.

### 1. VM Fault Metrics

- `node_exporter:node_vmstat_pgfault_rate_5m`: This rule exposes a five-minute per-second rate from **node_vmstat_pgfault**. It is the compact operational summary for this part of the component.

  > Expr: rate(node_vmstat_pgfault[5m])

- `node_exporter:node_vmstat_pgmajfault_rate_5m`: This rule exposes a five-minute per-second rate from **node_vmstat_pgmajfault**. It is the compact operational summary for this part of the component.

  > Expr: rate(node_vmstat_pgmajfault[5m])

- `node_exporter:node_vmstat_majfault_ratio_5m`: This rule exposes a five-minute ratio from **node_vmstat_pgmajfault**, **node_vmstat_pgfault**. It is the compact operational summary for this part of the component.
  > Expr: rate(node_vmstat_pgmajfault[5m]) / clamp_min(rate(node_vmstat_pgfault[5m]), 1e-6) and on(cluster, instance) (rate(node_vmstat_pgfault[5m]) > 0)

### 2. Scheduler Churn Metrics

- `node_exporter:node_procs_blocked:avg_5m`: This rule exposes a five-minute average from **node_procs_blocked**. It is the compact operational summary for this part of the component.

  > Expr: avg_over_time(node_procs_blocked{job="node-exporter"}[5m])

- `node_exporter:node_context_switches_per_second:rate_5m`: This rule exposes a five-minute per-second rate from **node_context_switches_total**. It is the compact operational summary for this part of the component.

  > Expr: rate(node_context_switches_total{job="node-exporter"}[5m])

### 3. Softnet Metrics

- `node_exporter:node_softnet_processed_rate_5m`: This rule exposes a five-minute per-second rate from **node_softnet_processed_total**. It is the compact operational summary for this part of the component.

  > Expr: sum without (cpu) (rate(node_softnet_processed_total{job="node-exporter"}[5m]))

- `node_exporter:node_softnet_drop_ratio_5m`: This rule exposes a five-minute ratio from **node_softnet_dropped_total**, **node_softnet_processed_total**. It is the compact operational summary for this part of the component.

  > Expr: sum without (cpu) (rate(node_softnet_dropped_total{job="node-exporter"}[5m])) / clamp_min(sum without (cpu) (rate(node_softnet_dropped_total{job="node-exporter"}[5m])) + sum without (cpu) (rate(node_softnet_processed_total{job="node-exporter"}[5m])), 1e-6)

- `node_exporter:node_softnet_squeezed_ratio_5m`: This rule exposes a five-minute ratio from **node_softnet_times_squeezed_total**, **node_softnet_processed_total**, **node_softnet_dropped_total**. It is the compact operational summary for this part of the component.

  > Expr: sum without (cpu) (rate(node_softnet_times_squeezed_total{job="node-exporter"}[5m])) / clamp_min(sum without (cpu) (rate(node_softnet_processed_total{job="node-exporter"}[5m])) + sum without (cpu) (rate(node_softnet_dropped_total{job="node-exporter"}[5m])), 1e-6)

- `node_exporter:node_softnet_backlog_delay_seconds_5m`: This rule exposes a five-minute current level from **node_softnet_backlog_len**, **node_softnet_processed_total**. It is the compact operational summary for this part of the component.

  > Expr: max_over_time((sum without (cpu) (node_softnet_backlog_len{job="node-exporter"}))[5m:]) / clamp_min(sum without (cpu) (rate(node_softnet_processed_total{job="node-exporter"}[5m])), 1e-6)

### 4. Scheduler Wait Metrics

- `node_exporter:node_sched_wait_share_5m`: This rule exposes a five-minute current level from **node_schedstat_waiting_seconds_total**, **node_schedstat_running_seconds_total**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum without (cpu) (rate(node_schedstat_waiting_seconds_total{job="node-exporter"}[5m])) / clamp_min(sum without (cpu) (rate(node_schedstat_waiting_seconds_total{job="node-exporter"}[5m])) + sum without (cpu) (rate(node_schedstat_running_seconds_total{job="node-exporter"}[5m])), 1e-6)

### 5. PSI Metrics

- `node_exporter:node_pressure_cpu_wait_ratio_5m`: This rule exposes a five-minute ratio from **node_pressure_cpu_waiting_seconds_total**. It is the latency or waiting-time summary for this part of the component.

  > Expr: rate(node_pressure_cpu_waiting_seconds_total[5m])

- `node_exporter:node_pressure_io_wait_ratio_5m`: This rule exposes a five-minute ratio from **node_pressure_io_waiting_seconds_total**. It is the latency or waiting-time summary for this part of the component.

  > Expr: rate(node_pressure_io_waiting_seconds_total[5m])

- `node_exporter:node_pressure_mem_wait_ratio_5m`: This rule exposes a five-minute ratio from **node_pressure_memory_waiting_seconds_total**. It is the latency or waiting-time summary for this part of the component.
  > Expr: rate(node_pressure_memory_waiting_seconds_total[5m])

### 6. TCP And UDP Health Metrics

- `node_exporter:node_net_tcp_conn_estab:avg5m`: This rule exposes a five-minute average from **node_netstat_Tcp_CurrEstab**. It is the compact operational summary for this part of the component.

  > Expr: avg_over_time(node_netstat_Tcp_CurrEstab[5m])

- `node_exporter:node_net_tcp_retrans_timeout:rate5m`: This rule exposes a five-minute per-second rate from **node_netstat_Tcp_RetransSegs**, **node_netstat_TcpExt_TCPTimeouts**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance, job) (rate(node_netstat_Tcp_RetransSegs[5m]) + rate(node_netstat_TcpExt_TCPTimeouts[5m]))

- `node_exporter:node_net_tcp_listen_drops:rate5m`: This rule exposes a five-minute per-second rate from **node_netstat_TcpExt_ListenDrops**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance, job) (rate(node_netstat_TcpExt_ListenDrops[5m]))

- `node_exporter:node_net_udp_error_events:rate5m`: This rule exposes a five-minute per-second rate from **node_netstat_Udp_InErrors**, **node_netstat_Udp_RcvbufErrors**. It is the failure-focused summary for this part of the component.
  > Expr: sum by (cluster, instance, job) (rate(node_netstat_Udp_InErrors[5m]) + rate(node_netstat_Udp_RcvbufErrors[5m]))

### 7. Primary NIC Metrics

- `node_exporter:node_net_rx_bytes_ens33:rate5m`: Five-minute receive throughput on the hard-coded `ens33` interface used by the current values file.

  > Expr: sum by (cluster, instance, job) (rate(node_network_receive_bytes_total{device="ens33"}[5m]))

- `node_exporter:node_net_tx_bytes_ens33:rate5m`: Five-minute transmit throughput on the hard-coded `ens33` interface used by the current values file.

  > Expr: sum by (cluster, instance, job) (rate(node_network_transmit_bytes_total{device="ens33"}[5m]))

- `node_exporter:node_net_rx_pps_ens33:rate5m`: This rule exposes a five-minute per-second rate from **node_network_receive_packets_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance, job) (rate(node_network_receive_packets_total{device="ens33"}[5m]))

- `node_exporter:node_net_tx_pps_ens33:rate5m`: This rule exposes a five-minute per-second rate from **node_network_transmit_packets_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance, job) (rate(node_network_transmit_packets_total{device="ens33"}[5m]))

- `node_exporter:node_net_rx_loss_error_ratio_ens33:rate5m`: This rule exposes a five-minute ratio from **node_network_receive_drop_total**, **node_network_receive_errs_total**, **node_network_receive_packets_total**. It is the failure-focused summary for this part of the component.

  > Expr: (sum by (cluster, instance, job) (rate(node_network_receive_drop_total{device="ens33"}[5m]) + rate(node_network_receive_errs_total{device="ens33"}[5m]))) / (sum by (cluster, instance, job) (rate(node_network_receive_packets_total{device="ens33"}[5m])) + 1e-6)

- `node_exporter:node_net_tx_loss_error_ratio_ens33:rate5m`: This rule exposes a five-minute ratio from **node_network_transmit_drop_total**, **node_network_transmit_errs_total**, **node_network_transmit_packets_total**. It is the failure-focused summary for this part of the component.

  > Expr: (sum by (cluster, instance, job) (rate(node_network_transmit_drop_total{device="ens33"}[5m]) + rate(node_network_transmit_errs_total{device="ens33"}[5m]))) / (sum by (cluster, instance, job) (rate(node_network_transmit_packets_total{device="ens33"}[5m])) + 1e-6)

- `node_exporter:node_net_rx_drop_ratio_ens33:rate5m`: This rule exposes a five-minute ratio from **node_network_receive_drop_total**, **node_network_receive_packets_total**. It is the compact operational summary for this part of the component.

  > Expr: (sum by (cluster, instance, job) (rate(node_network_receive_drop_total{device="ens33"}[5m])) / sum by (cluster, instance, job) (rate(node_network_receive_packets_total{device="ens33"}[5m]) + 1e-6))

- `node_exporter:node_net_tx_drop_ratio_ens33:rate5m`: This rule exposes a five-minute ratio from **node_network_transmit_drop_total**. It is the compact operational summary for this part of the component.

  > Expr: (sum by (cluster, instance, job) (rate(node_network_transmit_drop_total{device="ens33"}[5m])) / sum by (cluster, instance, job) (rate(node_network_transmit_drop_total{device="ens33"}[5m]) + 1e-6))

### 8. Memory Composition Metrics

- `node_exporter:node_mem_utilization_ratio`: This rule exposes the ratio from **node_memory_MemAvailable_bytes**, **node_memory_Buffers_bytes**, **node_memory_Cached_bytes**, and related inputs. It is the saturation or headroom summary for this part of the component.

  > Expr: 1 - ((node_memory_MemAvailable_bytes{job="node-exporter"} or (node_memory_Buffers_bytes{job="node-exporter"} + node_memory_Cached_bytes{job="node-exporter"} + node_memory_MemFree_bytes{job="node-exporter"} + node_memory_SReclaimable_bytes{job="node-exporter"} - node_memory_Shmem_bytes{job="node-exporter"})) / node_memory_MemTotal_bytes{job="node-exporter"})

- `node_exporter:node_mem_headroom_ratio`: This rule exposes the ratio from **node_memory_MemAvailable_bytes**, **node_memory_MemTotal_bytes**. It is the saturation or headroom summary for this part of the component.

  > Expr: node_memory_MemAvailable_bytes / on(cluster, instance, job) clamp_min(node_memory_MemTotal_bytes, 1)

- `node_exporter:node_mem_headroom_slope_bytes_per_sec_5m`: This rule exposes a five-minute byte-valued level from **node_memory_MemAvailable_bytes**. It is the saturation or headroom summary for this part of the component.

  > Expr: deriv(node_memory_MemAvailable_bytes[5m])

- `node_exporter:node_mem_cache_ratio`: This rule exposes the ratio from **node_memory_Cached_bytes**, **node_memory_MemTotal_bytes**. It is the compact operational summary for this part of the component.

  > Expr: node_memory_Cached_bytes / on(cluster, instance, job) clamp_min(node_memory_MemTotal_bytes, 1)

- `node_exporter:node_mem_anon_ratio`: This rule exposes the ratio from **node_memory_AnonPages_bytes**, **node_memory_MemTotal_bytes**. It is the compact operational summary for this part of the component.

  > Expr: node_memory_AnonPages_bytes / on(cluster, instance, job) clamp_min(node_memory_MemTotal_bytes, 1)

- `node_exporter:node_mem_anon_hot_ratio`: This rule exposes the ratio from **node_memory_Active_anon_bytes**, **node_memory_Inactive_anon_bytes**. It is the compact operational summary for this part of the component.

  > Expr: node_memory_Active_anon_bytes / on(cluster, instance, job) clamp_min((node_memory_Active_anon_bytes + node_memory_Inactive_anon_bytes), 1)

- `node_exporter:node_mem_dirty_writeback_ratio`: This rule exposes the ratio from **node_memory_Dirty_bytes**, **node_memory_Writeback_bytes**, **node_memory_MemTotal_bytes**. It is the compact operational summary for this part of the component.

  > Expr: (node_memory_Dirty_bytes + node_memory_Writeback_bytes) / on(cluster, instance, job) clamp_min(node_memory_MemTotal_bytes, 1)

- `node_exporter:node_mem_kernel_hard_reclaim_ratio`: This rule exposes the ratio from **node_memory_SUnreclaim_bytes**, **node_memory_PageTables_bytes**, **node_memory_KernelStack_bytes**, and related inputs. It is the compact operational summary for this part of the component.

  > Expr: (node_memory_SUnreclaim_bytes+ node_memory_PageTables_bytes + node_memory_KernelStack_bytes + node_memory_Unevictable_bytes + node_memory_Mlocked_bytes) / on(cluster, instance, job) clamp_min(node_memory_MemTotal_bytes, 1)

### 9. Root Filesystem Metrics

- `node_exporter:node_filesystem_root:avail_ratio`: Available-capacity ratio for the root mount only. The rule intentionally collapses labels so `/` becomes one value per node.

  > Expr: max without(device, fstype, mountpoint, device_error) (node_filesystem_avail_bytes{job="node-exporter",mountpoint="/"} ) / max without(device, fstype, mountpoint, device_error) (node_filesystem_size_bytes{job="node-exporter",mountpoint="/"})

- `node_exporter:node_filesystem_root:inode_free_ratio`: Free-inode ratio for the root mount. It catches inode exhaustion even when byte capacity still looks healthy.

  > Expr: max without(device, fstype, mountpoint, device_error) (node_filesystem_files_free{job="node-exporter",mountpoint="/"} ) / max without(device, fstype, mountpoint, device_error) (node_filesystem_files{job="node-exporter",mountpoint="/"})

- `node_exporter:node_filesystem_root:readonly`: Readonly state of the root mount. A non-zero value is an immediate write-availability problem.

  > Expr: max without(device, fstype, mountpoint, device_error) (node_filesystem_readonly{job="node-exporter",mountpoint="/"})

- `node_exporter:node_filesystem_root:device_error`: Device-error state of the root filesystem after label reduction.
  > Expr: max without(device, fstype, mountpoint, device_error) (node_filesystem_device_error{job="node-exporter",mountpoint="/"})

### 10. File Descriptor Metrics

- `node_exporter:node_filefd:utilization_ratio`: This rule exposes the ratio from **node_filefd_allocated**, **node_filefd_maximum**. It is the saturation or headroom summary for this part of the component.

  > Expr: node_filefd_allocated / node_filefd_maximum

- `node_exporter:node_filefd:allocated_delta_5m`: This rule exposes a five-minute current level from **node_filefd_allocated**. It is the compact operational summary for this part of the component.

  > Expr: delta(node_filefd_allocated[5m])

### 11. Disk Metrics

- `node_exporter:node_disk:utilization_max_5m`: Maximum five-minute disk busy ratio across disks matching `^sd[a-z]+$`. It intentionally reports the busiest physical disk rather than an average.

  > Expr: max by (cluster, instance) (rate(node_disk_io_time_seconds_total{device=~"^sd[a-z]+$"}[5m]))

- `node_exporter:node_disk:queue_depth_max_5m`: Maximum five-minute weighted IO time rate across `sd*` disks. In this ruleset it is used as a queue-depth or congestion proxy.

  > Expr: max by (cluster, instance) (rate(node_disk_io_time_weighted_seconds_total{device=~"^sd[a-z]+$"}[5m]))

- `node_exporter:node_disk:io_bps_total_5m`: This rule exposes a five-minute current level from **node_disk_read_bytes_total**, **node_disk_written_bytes_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_disk_read_bytes_total{device=~"^sd[a-z]+$"}[5m])) + sum by (cluster, instance) (rate(node_disk_written_bytes_total{device=~"^sd[a-z]+$"}[5m]))

- `node_exporter:node_disk:io_iops_total_5m`: This rule exposes a five-minute current level from **node_disk_reads_completed_total**, **node_disk_writes_completed_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_disk_reads_completed_total{device=~"^sd[a-z]+$"}[5m])) + sum by (cluster, instance) (rate(node_disk_writes_completed_total{device=~"^sd[a-z]+$"}[5m]))

- `node_exporter:node_disk:read_latency_avg_5m`: This rule exposes a five-minute average from **node_disk_read_time_seconds_total**, **node_disk_reads_completed_total**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_disk_read_time_seconds_total{device=~"^sd[a-z]+$"}[5m])) / clamp_min(sum by (cluster, instance) (rate(node_disk_reads_completed_total{device=~"^sd[a-z]+$"}[5m])), 1)

- `node_exporter:node_disk:write_latency_avg_5m`: This rule exposes a five-minute average from **node_disk_write_time_seconds_total**, **node_disk_writes_completed_total**. It is the latency or waiting-time summary for this part of the component.
  > Expr: sum by (cluster, instance) (rate(node_disk_write_time_seconds_total{device=~"^sd[a-z]+$"}[5m])) / clamp_min(sum by (cluster, instance) (rate(node_disk_writes_completed_total{device=~"^sd[a-z]+$"}[5m])), 1)

### 12. CPU Metrics

- `node_exporter:node_cpu_util_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the saturation or headroom summary for this part of the component.

  > Expr: avg by (cluster, instance) (sum without (mode) (rate(node_cpu_seconds_total{job="node-exporter",mode!="idle",mode!="iowait",mode!="steal"}[5m])))

- `node_exporter:node_cpu_mode_user_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_cpu_seconds_total{mode="user"}[5m])) / sum by (cluster, instance) (rate(node_cpu_seconds_total[5m]))

- `node_exporter:node_cpu_mode_system_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_cpu_seconds_total{mode="system"}[5m])) / sum by (cluster, instance) (rate(node_cpu_seconds_total[5m]))

- `node_exporter:node_cpu_mode_idle_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) / sum by (cluster, instance) (rate(node_cpu_seconds_total[5m]))

- `node_exporter:node_cpu_mode_iowait_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_cpu_seconds_total{mode="iowait"}[5m])) / sum by (cluster, instance) (rate(node_cpu_seconds_total[5m]))

- `node_exporter:node_cpu_mode_irq_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_cpu_seconds_total{mode="irq"}[5m])) / sum by (cluster, instance) (rate(node_cpu_seconds_total[5m]))

- `node_exporter:node_cpu_mode_softirq_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_cpu_seconds_total{mode="softirq"}[5m])) / sum by (cluster, instance) (rate(node_cpu_seconds_total[5m]))

- `node_exporter:node_cpu_mode_steal_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(node_cpu_seconds_total{mode="steal"}[5m])) / sum by (cluster, instance) (rate(node_cpu_seconds_total[5m]))

- `node_exporter:node_cpu_mode_nice_ratio`: This rule exposes the ratio from **node_cpu_seconds_total**. It is the compact operational summary for this part of the component.
  > Expr: sum by (cluster, instance) (rate(node_cpu_seconds_total{mode="nice"}[5m])) / sum by (cluster, instance) (rate(node_cpu_seconds_total[5m]))

## APIService Metrics

- `kube:apiservice:unavailable:max`: This rule exposes the current level from **aggregator_unavailable_apiservice**. It is the compact operational summary for this part of the component.
  > Expr: max by (cluster) (aggregator_unavailable_apiservice)

## kube-apiserver Metrics

- `kube:apiserver:admission_controller:admission:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_admission_controller_admission_duration_seconds_count**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, type) (rate(apiserver_admission_controller_admission_duration_seconds_count[5m]))

- `kube:apiserver:admission_controller:rejected:ratio5m`: This rule exposes a five-minute ratio from **apiserver_admission_controller_admission_duration_seconds_count**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, type) (rate(apiserver_admission_controller_admission_duration_seconds_count{rejected="true"}[5m])) / clamp_min(sum by (cluster, type) (rate(apiserver_admission_controller_admission_duration_seconds_count[5m])), 1e-9)

- `kube:apiserver:admission_controller:admission_webhook_error_ratio:ratio5m`: This rule exposes a five-minute ratio from **apiserver_admission_webhook_request_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, type) (rate(apiserver_admission_webhook_request_total{code!~"2.."}[5m])) / clamp_min(sum by (cluster, operation, type) (rate(apiserver_admission_webhook_request_total[5m])), 1e-9)

- `kube:apiserver:authentication:attempts_fail_ratio:ratio5m`: This rule exposes a five-minute ratio from **authentication_attempts**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(authentication_attempts{result="failure"}[5m])) / clamp_min(sum by (cluster) (rate(authentication_attempts{result="failure"}[5m]) + rate(authentication_attempts{result="success"}[5m])), 1e-9)

- `kube:apiserver:serviceaccount:tokenrequest_stale_tokens:rate5m`: This rule exposes a five-minute per-second rate from **serviceaccount_stale_tokens_total**. It is the inventory-style summary for this part of the component.

  > Expr: sum by (cluster) (rate(serviceaccount_stale_tokens_total[5m]))

- `kube:apiserver:requests:inflight:max5m`: This rule exposes a five-minute current level from **apiserver_current_inflight_requests**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster) (max_over_time(apiserver_current_inflight_requests[5m]))

- `kube:apiserver:requests:inqueue:max5m`: This rule exposes a five-minute current level from **apiserver_current_inqueue_requests**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster) (max_over_time(apiserver_current_inqueue_requests[5m]))

- `kube:apiserver:requests:qps:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_request_total**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_request_total{subresource!~"/(healthz|livez|readyz)"}[5m]))

- `kube:apiserver:requests:server_error_ratio:ratio5m`: This rule exposes a five-minute ratio from **apiserver_request_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_request_total{code=~"5..",subresource!~"/(healthz|livez|readyz)"}[5m])) / clamp_min(sum by (cluster) (rate(apiserver_request_total{subresource!~"/(healthz|livez|readyz)"}[5m])), 1e-6)

- `kube:apiserver:requests:sli_duration:avg5m`: This rule exposes a five-minute average from **apiserver_request_sli_duration_seconds_sum**, **apiserver_request_sli_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_request_sli_duration_seconds_sum{subresource!~"/(healthz|livez|readyz)"}[5m])) / clamp_min(sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{subresource!~"/(healthz|livez|readyz)"}[5m])), 1e-6)

- `kube:apiserver:requests:duration:avg5m`: This rule exposes a five-minute average from **apiserver_request_duration_seconds_sum**, **apiserver_request_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_request_duration_seconds_sum{subresource!~"/(healthz|livez|readyz)"}[5m])) / clamp_min(sum by (cluster) (rate(apiserver_request_duration_seconds_count{subresource!~"/(healthz|livez|readyz)"}[5m])), 1e-6)

- `kube:apiserver:apf:executing_seats:max5m`: This rule exposes a five-minute current level from **apiserver_flowcontrol_current_executing_seats**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (max_over_time(apiserver_flowcontrol_current_executing_seats[5m]))

- `kube:apiserver:apf:inqueue_seats:max5m`: This rule exposes a five-minute current level from **apiserver_flowcontrol_current_inqueue_seats**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (max_over_time(apiserver_flowcontrol_current_inqueue_seats[5m]))

- `kube:apiserver:apf:current_limit_seats:sum_max5m`: This rule exposes a five-minute sum from **apiserver_flowcontrol_current_limit_seats**. It is the inventory-style summary for this part of the component.

  > Expr: sum by (cluster) (max_over_time(apiserver_flowcontrol_current_limit_seats[5m]))

- `kube:apiserver:apf:seat_utilization:avg5m`: This rule exposes a five-minute average from **apiserver_flowcontrol_priority_level_seat_utilization_sum**, **apiserver_flowcontrol_priority_level_seat_utilization_count**. It is the saturation or headroom summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_flowcontrol_priority_level_seat_utilization_sum{phase="executing"}[5m])) / clamp_min(sum by (cluster) (rate(apiserver_flowcontrol_priority_level_seat_utilization_count{phase="executing"}[5m])), 1e-6)

- `kube:apiserver:apf:dispatched_requests:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_flowcontrol_dispatched_requests_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_flowcontrol_dispatched_requests_total[5m]))

- `kube:apiserver:apf:concurrency_in_use:max5m`: This rule exposes a five-minute current level from **apiserver_flowcontrol_request_concurrency_in_use**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (max_over_time(apiserver_flowcontrol_request_concurrency_in_use[5m]))

- `kube:apiserver:storage:list:qps:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_storage_list_total**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_storage_list_total[5m]))

- `kube:apiserver:storage:etcd_size_bytes`: This rule exposes the byte-valued level from **apiserver_storage_size_bytes**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (apiserver_storage_size_bytes)

- `kube:apiserver:watchcache:initializations:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_watch_cache_initializations_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_watch_cache_initializations_total[5m]))

- `kube:apiserver:watchcache:consistent_read_fallback_ratio:ratio5m`: This rule exposes a five-minute ratio from **apiserver_watch_cache_consistent_read_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_watch_cache_consistent_read_total{fallback="true"}[5m])) / clamp_min(sum by (cluster) (rate(apiserver_watch_cache_consistent_read_total[5m])), 1e-6)

- `kube:apiserver:cache_list:qps:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_cache_list_total**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_cache_list_total[5m]))

- `kube:apiserver:authn:token_cache:miss_ratio:ratio5m`: This rule exposes a five-minute ratio from **authentication_token_cache_request_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(authentication_token_cache_request_total{status="miss"}[5m])) / clamp_min(sum by (cluster) (rate(authentication_token_cache_request_total[5m])), 1e-6)

- `kube:apiserver:authn:token_cache:active_fetch:max5m`: This rule exposes a five-minute current level from **authentication_token_cache_active_fetch_count**. It is the compact operational summary for this part of the component.

  > Expr: max by (cluster) (max_over_time(authentication_token_cache_active_fetch_count[5m]))

- `kube:apiserver:audit:events:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_audit_event_total**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_audit_event_total[5m]))

- `kube:apiserver:audit:requests_rejected:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_audit_requests_rejected_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_audit_requests_rejected_total[5m]))

- `kube:apiserver:service_repair:reconcile_errors:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_clusterip_repair_reconcile_errors_total**, **apiserver_nodeport_repair_reconcile_errors_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(apiserver_clusterip_repair_reconcile_errors_total[5m]) + rate(apiserver_nodeport_repair_reconcile_errors_total[5m]))

- `kube:apiserver:watchcache:init_events:rate5m`: This rule exposes a five-minute per-second rate from **apiserver_init_events_total**. It is the compact operational summary for this part of the component.
  > Expr: sum by (cluster) (rate(apiserver_init_events_total[5m]))

## kube-controller-manager Metrics

- `kube:controller_manager:endpointslice:sync_failures:rate5m`: This rule exposes a five-minute per-second rate from **endpoint_slice_controller_syncs**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(endpoint_slice_controller_syncs{result!="success"}[5m]))

- `kube:controller_manager:endpointslice:slices_actual_to_desired:ratio5m`: This rule exposes a five-minute ratio from **endpoint_slice_controller_num_endpoint_slices**, **endpoint_slice_controller_desired_endpoint_slices**. It is the compact operational summary for this part of the component.

  > Expr: (sum by (cluster) (avg_over_time(endpoint_slice_controller_num_endpoint_slices[5m]))) / clamp_min((sum by (cluster) (avg_over_time(endpoint_slice_controller_desired_endpoint_slices[5m]))), 1)

- `kube:controller_manager:endpointslice_mirroring:slices_actual_to_desired:ratio5m`: This rule exposes a five-minute ratio from **endpoint_slice_mirroring_controller_num_endpoint_slices**, **endpoint_slice_mirroring_controller_desired_endpoint_slices**. It is the compact operational summary for this part of the component.

  > Expr: (sum by (cluster) (avg_over_time(endpoint_slice_mirroring_controller_num_endpoint_slices[5m]))) / clamp_min((sum by (cluster) (avg_over_time(endpoint_slice_mirroring_controller_desired_endpoint_slices[5m]))), 1)

- `kube:service_controller:nodesync_error:rate5m`: This rule exposes a five-minute per-second rate from **service_controller_nodesync_error_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(service_controller_nodesync_error_total[5m]))

- `kube:node_authorizer:graph_actions_duration_seconds:avg5m`: This rule exposes a five-minute average from **node_authorizer_graph_actions_duration_seconds_sum**, **node_authorizer_graph_actions_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster) (rate(node_authorizer_graph_actions_duration_seconds_sum[5m])) / clamp_min(sum by (cluster) (rate(node_authorizer_graph_actions_duration_seconds_count[5m])), 1e-9)

- `kube:node_collector:evictions_total:rate5m`: This rule exposes a five-minute per-second rate from **node_collector_evictions_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(node_collector_evictions_total[5m]))

- `kube:node_collector:unhealthy_nodes:ratio`: This rule exposes the ratio from **node_collector_unhealthy_nodes_in_zone**, **node_collector_zone_size**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (node_collector_unhealthy_nodes_in_zone) / clamp_min(sum by (cluster) (node_collector_zone_size), 1)

- `kube:node_ipam:cidrset_usage_cidrs:remaining`: This rule exposes the current level from **node_ipam_controller_cidrset_usage_cidrs**. It is the compact operational summary for this part of the component.

  > Expr: 1 - max by (cluster) (node_ipam_controller_cidrset_usage_cidrs)

- `kube:storage:ephemeral_volume_controller:create_failures:ratio5m`: This rule exposes a five-minute ratio from **ephemeral_volume_controller_create_failures_total**, **ephemeral_volume_controller_create_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(ephemeral_volume_controller_create_failures_total[5m])) / clamp_min(sum by (cluster) (rate(ephemeral_volume_controller_create_total[5m])), 1e-9)

- `kube:cronjob_controller:job_creation_skew_seconds:avg5m`: This rule exposes a five-minute average from **cronjob_controller_job_creation_skew_duration_seconds_sum**, **cronjob_controller_job_creation_skew_duration_seconds_count**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(cronjob_controller_job_creation_skew_duration_seconds_sum[5m])) / clamp_min(sum by (cluster) (rate(cronjob_controller_job_creation_skew_duration_seconds_count[5m])), 1e-9)

- `kube:taint_eviction_controller:pod_deletions_total:rate5m`: This rule exposes a five-minute per-second rate from **taint_eviction_controller_pod_deletions_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(taint_eviction_controller_pod_deletions_total[5m]))

- `kube:garbagecollector:resources_sync_error_total:rate5m`: This rule exposes a five-minute per-second rate from **garbagecollector_controller_resources_sync_error_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(garbagecollector_controller_resources_sync_error_total[5m]))

- `kube:root_ca_cert_publisher:sync_errors:ratio5m`: This rule exposes a five-minute ratio from **root_ca_cert_publisher_sync_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(root_ca_cert_publisher_sync_total{code!="200"}[5m])) / clamp_min(sum by (cluster) (rate(root_ca_cert_publisher_sync_total[5m])), 1e-9)

- `kube:controller_manager:running_managed_controllers:up`: This rule exposes the current level from **running_managed_controllers**. It is the compact operational summary for this part of the component.

  > Expr: min by (cluster, manager, name) (running_managed_controllers)

- `kube:controller_manager:running_managed_controllers:count`: This rule exposes the count from **running_managed_controllers**. It is the inventory-style summary for this part of the component.
  > Expr: sum by (cluster, manager) (running_managed_controllers)

## kube-scheduler Metrics

- `kube:scheduler:pending_pods:total`: This rule exposes the current level from **scheduler_pending_pods**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (scheduler_pending_pods)

- `kube:scheduler:pod_scheduling_attempts:avg5m`: This rule exposes a five-minute average from **scheduler_pod_scheduling_attempts_sum**, **scheduler_pod_scheduling_attempts_count**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(scheduler_pod_scheduling_attempts_sum[5m])) / clamp_min(sum by (cluster) (rate(scheduler_pod_scheduling_attempts_count[5m])), 1e-9)

- `kube:scheduler:cache_size:assumed_pods`: This rule exposes the current level from **scheduler_scheduler_cache_size**, **assumed_pods**. It is the inventory-style summary for this part of the component.

  > Expr: max by (cluster) (scheduler_scheduler_cache_size{type="assumed_pods"})

- `kube:scheduler:scheduling_algorithm_duration_seconds:avg5m`: This rule exposes a five-minute average from **scheduler_scheduling_algorithm_duration_seconds_sum**, **scheduler_scheduling_algorithm_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.
  > Expr: sum by (cluster) (rate(scheduler_scheduling_algorithm_duration_seconds_sum[5m])) / clamp_min(sum by (cluster) (rate(scheduler_scheduling_algorithm_duration_seconds_count[5m])), 1e-9)

### kubelet Metrics

- `kube:kubelet:http_inflight:total`: This rule exposes the current level from **kubelet_http_inflight_requests**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (kubelet_http_inflight_requests)

- `kube:kubelet:http_effective_service_time_seconds:est5m`: Estimated effective service time, computed as current in-flight requests divided by five-minute request rate. It approximates how slow kubelet feels under load.

  > Expr: sum by (cluster) (kubelet_http_inflight_requests) / clamp_min(sum by (cluster) (rate(kubelet_http_requests_total[5m])), 1e-9)

- `kube:kubelet:storage_op:latency_seconds:avg5m`: This rule exposes a five-minute average from **storage_operation_duration_seconds_sum**, **storage_operation_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster) (rate(storage_operation_duration_seconds_sum[5m])) / clamp_min(sum by (cluster) (rate(storage_operation_duration_seconds_count[5m])), 1e-9)

- `kube:kubelet:storage_op:qps:rate5m`: This rule exposes a five-minute per-second rate from **storage_operation_duration_seconds_count**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster) (rate(storage_operation_duration_seconds_count[5m]))

- `kube:kubelet:storage_op:error_ratio:5m`: This rule exposes a five-minute ratio from **storage_operation_duration_seconds_count**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(storage_operation_duration_seconds_count{status!="success"}[5m])) / clamp_min(sum by (cluster) (rate(storage_operation_duration_seconds_count[5m])), 1e-9)

- `kube:pvc:used_ratio`: PVC used-capacity ratio derived from available bytes and total capacity. It is the practical fullness signal for each claim.

  > Expr: 1 - (min by (cluster, namespace, persistentvolumeclaim) (kubelet_volume_stats_available_bytes) / clamp_min(max by (cluster, namespace, persistentvolumeclaim) (kubelet_volume_stats_capacity_bytes), 1))

- `kube:pv:abnormal:count`: Count of persistent volumes not in the `Bound` phase. It compresses PV phase state into one abnormal-volume number.

  > Expr: sum by (cluster) (kube_persistentvolume_status_phase{phase=~"Failed|Released|Available|Pending"} == 1)

- `kube:kubelet:pinning_error_ratio:5m`: This rule exposes a five-minute ratio from **kubelet_cpu_manager_pinning_errors_total**, **kubelet_memory_manager_pinning_errors_total**, **kubelet_cpu_manager_pinning_requests_total**, and related inputs. It is the failure-focused summary for this part of the component.

  > Expr: (sum by (cluster) (rate(kubelet_cpu_manager_pinning_errors_total[5m])) + sum by (cluster) (rate(kubelet_memory_manager_pinning_errors_total[5m]))) / clamp_min((sum by (cluster) (rate(kubelet_cpu_manager_pinning_requests_total[5m])) + sum by (cluster) (rate(kubelet_memory_manager_pinning_requests_total[5m]))), 1e-9)

- `kube:kubelet:topology_admission_error_ratio:5m`: This rule exposes a five-minute ratio from **kubelet_topology_manager_admission_errors_total**, **kubelet_topology_manager_admission_requests_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(kubelet_topology_manager_admission_errors_total[5m])) / clamp_min(sum by (cluster) (rate(kubelet_topology_manager_admission_requests_total[5m])), 1e-9)

- `kube:kubelet:docker_ops_qps:rate5m`: This rule exposes a five-minute per-second rate from **kubelet_docker_operations_total**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster) (rate(kubelet_docker_operations_total[5m]))

- `kube:kubelet:docker_ops_latency_seconds:avg5m`: This rule exposes a five-minute average from **kubelet_docker_operations_duration_seconds_sum**, **kubelet_docker_operations_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster) (rate(kubelet_docker_operations_duration_seconds_sum[5m])) / clamp_min(sum by (cluster) (rate (kubelet_docker_operations_duration_seconds_count[5m])), 1e-9)

- `kube:kubelet:cni_ops_error_ratio:rate5m`: This rule exposes a five-minute ratio from **kubelet_network_plugin_operations_errors_total**, **kubelet_network_plugin_operations_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(kubelet_network_plugin_operations_errors_total[5m])) / clamp_min(sum by (cluster) (rate(kubelet_network_plugin_operations_total[5m])), 1e-9)

- `kube:kubelet:pod_start_latency_seconds:avg5m`: This rule exposes a five-minute average from **kubelet_pod_start_duration_seconds_sum**, **kubelet_pod_start_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster) (rate(kubelet_pod_start_duration_seconds_sum[5m])) / clamp_min(sum by (cluster) (rate(kubelet_pod_start_duration_seconds_count[5m])), 1e-9)

- `kube:kubelet:pod_status_sync_latency_seconds:avg5m`: This rule exposes a five-minute average from **kubelet_pod_status_sync_duration_seconds_sum**, **kubelet_pod_status_sync_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster) (rate(kubelet_pod_status_sync_duration_seconds_sum[5m])) / clamp_min(sum by (cluster) (rate(kubelet_pod_status_sync_duration_seconds_count[5m])), 1e-9)

- `kube:kubelet:pod_start_error_ratio:rate5m`: This rule exposes a five-minute ratio from **kubelet_started_pods_errors_total**, **kubelet_started_pods_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster) (rate(kubelet_started_pods_errors_total[5m])) / clamp_min(sum by (cluster) (rate(kubelet_started_pods_total[5m])), 1e-9)

- `kube:kubelet:pods_gap:desired_minus_working`: Difference between desired pods and working pods. A positive value means kubelet is behind the desired workload state.

  > Expr: sum by (cluster) (kubelet_desired_pods) - sum by (cluster) (kubelet_working_pods)

- `kube:kubelet:containers_exited_ratio`: Share of kubelet container-state entries currently marked as `exited`. It is a coarse signal for dead containers accumulating on nodes.
  > Expr: sum by (cluster) (kubelet_running_containers{container_state="exited"}) / clamp_min(sum by (cluster) (kubelet_running_containers), 1e-9)

### kube-proxy Metrics

- `kube:kubeproxy:ct_state_invalid_dropped_packets:rate5m`: This rule exposes a five-minute per-second rate from **kubeproxy_iptables_ct_state_invalid_dropped_packets_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(kubeproxy_iptables_ct_state_invalid_dropped_packets_total[5m]))

- `kube:kubeproxy:sync_full_proxy_rules_duration_seconds:avg5m`: This rule exposes a five-minute average from **kubeproxy_sync_full_proxy_rules_duration_seconds_sum**, **kubeproxy_sync_full_proxy_rules_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.
  > Expr: sum by (cluster) (rate(kubeproxy_sync_full_proxy_rules_duration_seconds_sum[5m])) / clamp_min(sum by (cluster) (rate(kubeproxy_sync_full_proxy_rules_duration_seconds_count[5m])), 1e-9)

## Container And Pod Metrics

These rules convert container-level telemetry into pod-level CPU, memory, filesystem, and lifecycle summaries.

### 1. Pod CPU Metrics

- `kube:pod_cpu_cores:rate5m`: Five-minute average pod CPU usage > Expressed directly in cores.

  > Expr: sum by (cluster, namespace, pod, node) (rate(container_cpu_usage_seconds_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"}[5m]))

- `kube:pod_cpu_cores:irate5m`: Faster-moving pod CPU usage in cores using `irate` over the current five-minute window.

  > Expr: sum by (cluster, namespace, pod, node) (irate(container_cpu_usage_seconds_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"}[5m]))

- `kube:pod_cpu_throttle_ratio:rate5m`: Share of pod CFS periods that were throttled over five minutes. This is the pod-level CPU quota pressure signal.

  > Expr: sum by (cluster, namespace, pod, node) (rate(container_cpu_cfs_throttled_periods_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"}[5m])) / clamp_min(sum by (cluster, namespace, pod, node) (rate(container_cpu_cfs_periods_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"}[5m])), 1)

- `kube:pod_cpu:utilization:5m`: Pod CPU usage divided by configured CPU limits. It turns raw core usage into a saturation-style ratio.

  > Expr: (sum by (cluster, namespace, pod) (rate(container_cpu_usage_seconds_total{job="kubelet", metrics_path="/metrics/cadvisor", namespace!="", pod!=""}[5m])) / clamp_min(sum by (cluster, namespace, pod) (kube_pod_container_resource_limits{job="kube-state-metrics", resource="cpu", unit="core", namespace!="", pod!=""}), 0.001))

### 2. Pod Memory Metrics

- `kube:pod_mem_working_set_bytes`: Current pod working-set memory summed across containers. This is the main active-memory footprint value per pod.

  > Expr: sum by (cluster, namespace, pod, node) (container_memory_working_set_bytes{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"})

- `kube:pod_mem_rss_bytes`: Current pod RSS memory summed across containers. It keeps resident non-cache memory visible at pod level.

  > Expr: sum by (cluster, namespace, pod, node) (container_memory_rss{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"})

- `kube:pod_mem_cache_bytes`: Current pod page-cache memory summed across containers. It helps separate cache-heavy pods from true memory-bound pods.

  > Expr: sum by (cluster, namespace, pod, node) (container_memory_cache{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"})

- `kube:pod_mem_cache_ratio`: Pod cache bytes divided by pod working-set bytes. It shows how much of the working set is cache-driven.

  > Expr: kube:pod_mem_cache_bytes / clamp_min(kube:pod_mem_working_set_bytes, 1)

- `kube:pod_mem_working_set_slope_bytes_per_sec:deriv5m`: Five-minute derivative of pod working-set memory in bytes per second. Negative or positive trends show whether a pod is shrinking or still growing.

  > Expr: sum by (cluster, namespace, pod, node) (deriv(container_memory_working_set_bytes{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"}[5m]))

- `kube:pod_oom_events:increase5m`: Five-minute increase in pod OOM events. It turns cumulative OOM counters into a recent-failure signal.

  > Expr: sum by (cluster, namespace, pod, node) (increase(container_oom_events_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"}[5m]))

- `kube:pod_mem:utilization:5m`: Pod working-set memory divided by configured memory limits. It is the pod-level memory saturation ratio.
  > Expr: (sum by (cluster, namespace, pod) (container_memory_working_set_bytes{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!=""}) / clamp_min(sum by (cluster, namespace, pod) (kube_pod_container_resource_limits{job="kube-state-metrics",resource="memory",unit="byte",namespace!="",pod!=""}), 1))

### 3. Pod Filesystem Metrics

- `kube:pod_fs_read_bps:rate5m`: This rule exposes a five-minute per-second rate from **container_fs_reads_bytes_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, namespace, pod, node) (rate(container_fs_reads_bytes_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!=""}[5m]))

- `kube:pod_fs_write_bps:rate5m`: This rule exposes a five-minute per-second rate from **container_fs_writes_bytes_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, namespace, pod, node) (rate(container_fs_writes_bytes_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!=""}[5m]))

- `kube:pod_fs_bps:rate5m`: This rule exposes a five-minute per-second rate from **kube:pod_fs_read_bps:rate5m**, **kube:pod_fs_write_bps:rate5m**. It is the compact operational summary for this part of the component.

  > Expr: kube:pod_fs_read_bps:rate5m + kube:pod_fs_write_bps:rate5m

- `kube:pod_fs_read_iops:rate5m`: This rule exposes a five-minute per-second rate from **container_fs_reads_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, namespace, pod, node) (rate(container_fs_reads_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!=""}[5m]))

- `kube:pod_fs_write_iops:rate5m`: This rule exposes a five-minute per-second rate from **container_fs_writes_total**. It is the compact operational summary for this part of the component.
  > Expr: sum by (cluster, namespace, pod, node) (rate(container_fs_writes_total{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!=""}[5m]))

### 4. Pod Process And Thread Metrics

- `kube:pod_processes`: Current total process count per pod.

  > Expr: sum by (cluster, namespace, pod, node) (container_processes{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"})

- `kube:pod_threads`: Current total thread count per pod.
  > Expr: sum by (cluster, namespace, pod, node) (container_threads{job="kubelet",metrics_path="/metrics/cadvisor",namespace!="",pod!="",container!="POD"})

### 5. cAdvisor Scrape Health

- `kube:kubelet_cadvisor_scrape_error`: Maximum observed cAdvisor scrape error per kubelet target. It is the pod-metrics collection health signal.
  > Expr: max by (cluster, node, instance) (container_scrape_error{job="kubelet",metrics_path="/metrics/cadvisor"})

## kube-state-metrics Metrics

These rules turn object-state metrics into health and capacity summaries for nodes, pods, workloads, and batch resources.

### 1. Node State Metrics

- `kube_state:node:not_ready`: Boolean-style node readiness failure signal where `1` means the node is not ready.

  > Expr: 1 - max by (cluster, node) (kube_node_status_condition{condition="Ready",status="true"})

- `kube_state:node:memory_pressure`: This rule exposes the current level from **kube_node_status_condition**. It is the saturation or headroom summary for this part of the component.

  > Expr: max by (cluster, node) (kube_node_status_condition{condition="MemoryPressure",status="true"})

- `kube_state:node:disk_pressure`: This rule exposes the current level from **kube_node_status_condition**. It is the saturation or headroom summary for this part of the component.

  > Expr: max by (cluster, node) (kube_node_status_condition{condition="DiskPressure",status="true"})

- `kube_state:node:pid_pressure`: This rule exposes the current level from **kube_node_status_condition**. It is the saturation or headroom summary for this part of the component.

  > Expr: max by (cluster, node) (kube_node_status_condition{condition="PIDPressure",status="true"})

- `kube_state:node:unschedulable`: This rule exposes the current level from **kube_node_spec_unschedulable**. It is the compact operational summary for this part of the component.

  > Expr: max by (cluster, node) (kube_node_spec_unschedulable)

- `kube_state:node:cpu_headroom_cores`: Remaining allocatable CPU after subtracting requested CPU. It is the node-level CPU headroom signal.

  > Expr: max by (cluster, node) (kube_node_status_allocatable{resource="cpu",unit="core"}) - (sum by (cluster, node) (kube_pod_container_resource_requests{resource="cpu",unit="core"}) or on (cluster, node) (0 \* max by (cluster, node) (kube_node_status_allocatable{resource="cpu",unit="core"})))

- `kube_state:node:mem_headroom_bytes`: Remaining allocatable memory after subtracting requested memory. It is the node-level memory headroom signal.
  > Expr: max by (cluster, node) (kube_node_status_allocatable{resource="memory",unit="byte"}) - (sum by (cluster, node) (kube_pod_container_resource_requests{resource="memory",unit="byte"}) or on (cluster, node) (0 \* max by (cluster, node) (kube_node_status_allocatable{resource="memory",unit="byte"})))

### 2. Pod State Metrics

- `kube_state:pod:container_restarts:increase5m`: This rule exposes a five-minute current level from **kube_pod_container_status_restarts_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (increase(kube_pod_container_status_restarts_total[5m]))

- `kube_state:pod:pod_not_ready:count`: This rule exposes the count from **kube_pod_status_ready**. It is the inventory-style summary for this part of the component.

  > Expr: sum by (cluster) (1 - kube_pod_status_ready{condition="true"})

- `kube_state:pod:pods_with_waiting:count`: This rule exposes the count from **kube_pod_container_status_waiting**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster) (max by (cluster, namespace, pod) (kube_pod_container_status_waiting) > 0)

- `kube_state:pod:pod_ready:ratio`: This rule exposes the ratio from **kube_pod_status_ready**. It is the compact operational summary for this part of the component.
  > Expr: avg by (cluster) (kube_pod_status_ready{condition="true"})

### 3. Deployment Metrics

- `kube_state:deployment:deploy_replicas_missing:sum`: This rule exposes the sum from **kube_deployment_spec_replicas**, **kube_deployment_status_replicas_available**. It is the inventory-style summary for this part of the component.

  > Expr: sum by (cluster, namespace) (clamp_min(kube_deployment_spec_replicas - kube_deployment_status_replicas_available, 0))

- `kube_state:deployment:deploy_availability:ratio`: This rule exposes the ratio from **kube_deployment_status_replicas_available**, **kube_deployment_spec_replicas**. It is the compact operational summary for this part of the component.
  > Expr: sum by (cluster, namespace) (kube_deployment_status_replicas_available) / clamp_min(sum by (cluster, namespace) (kube_deployment_spec_replicas), 1)

### 4. DaemonSet Metrics

- `kube_state:daemonset:daemonset_ready_missing:sum`: This rule exposes the sum from **kube_daemonset_status_desired_number_scheduled**, **kube_daemonset_status_number_ready**. It is the inventory-style summary for this part of the component.

  > Expr: sum by (cluster, namespace) (clamp_min(kube_daemonset_status_desired_number_scheduled - kube_daemonset_status_number_ready, 0))

- `kube_state:daemonset:daemonset_ready:ratio`: This rule exposes the ratio from **kube_daemonset_status_number_ready**, **kube_daemonset_status_desired_number_scheduled**. It is the compact operational summary for this part of the component.
  > Expr: sum by (cluster, namespace) (kube_daemonset_status_number_ready) / clamp_min(sum by (cluster, namespace) (kube_daemonset_status_desired_number_scheduled), 1)

### 5. Job Metrics

- `kube_state:job:jobs_failed:count`: This rule exposes the count from **kube_job_failed**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, namespace) (kube_job_failed{condition="true"})

- `kube_state:job:jobs_running:count`: This rule exposes the count from **kube_job_status_active**. It is the inventory-style summary for this part of the component.

  > Expr: sum by (cluster, namespace) (kube_job_status_active > 0)

- `kube_state:job:jobs_running_over_1h:count`: This rule exposes a 1-hour count from **kube_job_status_active**, **kube_job_status_start_time**. It is the inventory-style summary for this part of the component.
  > Expr: sum by (cluster, namespace) ((kube_job_status_active > 0) and ((time() - kube_job_status_start_time) > 3600))

### 6. CronJob Metrics

- `kube_state:cronjob:cronjobs_no_success_over_24h`: This rule exposes a 24-hour current level from **kube_cronjob_status_last_successful_time**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, namespace) ((time() - kube_cronjob_status_last_successful_time) > 86400)

- `kube_state:cronjob:cronjobs_no_schedule_over_2h:count`: Despite the rule name, the live PromQL behaves like another stale-success check based on `kube_cronjob_status_last_successful_time`. The > Expression in `values.yaml` is the final truth.

  > Expr: sum by (cluster, namespace) (((kube_cronjob_status_last_successful_time > bool 0) \* ((time() - kube_cronjob_status_last_successful_time) > bool 86400)))

- `kube_state:cronjob:cronjobs_active:count`: This rule exposes the count from **kube_cronjob_status_active**. It is the inventory-style summary for this part of the component.
  > Expr: sum by (cluster, namespace) (kube_cronjob_status_active > 0)

## Alertmanager Metrics

Alertmanager aggregation is intentionally small and focuses on reload failure and notification delivery quality.

### Alertmanager Status Metrics

- `alertmanager:config_reload_failed:bool5m`: This rule exposes a five-minute current level from **alertmanager_config_last_reload_successful**. It is the failure-focused summary for this part of the component.

  > Expr: max_over_time(alertmanager_config_last_reload_successful{cluster="rancher-monitor", container="alertmanager",job="monitor-kube-prometheus-st-alertmanager",namespace="monitor"}[5m]) == bool 0

- `alertmanager:notifications_failed_ratio15m`: This rule exposes a 15-minute ratio from **alertmanager_notifications_failed_total**, **alertmanager_notifications_total**. It is the failure-focused summary for this part of the component.

  > Expr: rate(alertmanager_notifications_failed_total{cluster="rancher-monitor", container="alertmanager",job="monitor-kube-prometheus-st-alertmanager",namespace="monitor"}[15m]) / ignoring (reason) group_left () rate(alertmanager_notifications_total{cluster="rancher-monitor", container="alertmanager",job="monitor-kube-prometheus-st-alertmanager",namespace="monitor"}[15m])

## Prometheus Metrics

Prometheus recording rules in this repository focus on notification delivery, service discovery, and remote write behavior.

### 1. Notification Metrics

- `prometheus:notification_queue_utilization:ratio5m`: This rule exposes a five-minute ratio from **prometheus_notifications_queue_length**, **prometheus_notifications_queue_capacity**. It is the saturation or headroom summary for this part of the component.

  > Expr: avg_over_time(prometheus_notifications_queue_length{job="monitor-kube-prometheus-st-prometheus", namespace="monitor"}[5m]) / min_over_time(prometheus_notifications_queue_capacity{job="monitor-kube-prometheus-st-prometheus", namespace="monitor"}[5m])

- `prometheus:notification_error_sendingalerts_to_alertmanger:ratio5m`: Five-minute ratio of notification errors to sent notifications. In the current values file, it uses the same formula as `prometheus:notification_error:ratio5m` under a separate rule name.

  > Expr: rate(prometheus_notifications_errors_total{job="monitor-kube-prometheus-st-prometheus",namespace="monitor"}[5m]) / rate(prometheus_notifications_sent_total{job="monitor-kube-prometheus-st-prometheus",namespace="monitor"}[5m])

- `prometheus:notification_connect_alertmanger:5m`: This rule exposes a five-minute current level from **prometheus_notifications_alertmanagers_discovered**. It is the compact operational summary for this part of the component.

  > Expr: max_over_time(prometheus_notifications_alertmanagers_discovered{job="monitor-kube-prometheus-st-prometheus",namespace="monitor"}[5m])

- `prometheus:notification_error:ratio5m`: This rule exposes a five-minute ratio from **prometheus_notifications_errors_total**, **prometheus_notifications_sent_total**. It is the failure-focused summary for this part of the component.
  > Expr: rate(prometheus_notifications_errors_total{job="monitor-kube-prometheus-st-prometheus",namespace="monitor"}[5m]) / rate(prometheus_notifications_sent_total{job="monitor-kube-prometheus-st-prometheus",namespace="monitor"}[5m])

### 2. Service Discovery Metrics

- `prometheus:sd:targets:sum`: This rule exposes the sum from **prometheus_sd_discovered_targets**. It is the inventory-style summary for this part of the component.

  > Expr: sum by (cluster) (max without (instance, pod, endpoint, service, job, namespace, name, config, prometheus, replica) (prometheus_sd_discovered_targets{name="scrape"}))

- `prometheus:sd:issues:increase5m`: This rule exposes a five-minute current level from **prometheus_sd_kubernetes_failures_total**, **prometheus_sd_updates_delayed_total**. It is the compact operational summary for this part of the component.
  > Expr: sum by (cluster) (max without (instance, pod, endpoint, service, job, namespace, name, config, prometheus, replica) (increase(prometheus_sd_kubernetes_failures_total[5m]))) + sum by (cluster) (max without (instance, pod, endpoint, service, job, namespace, name, config, prometheus, replica) (increase(prometheus_sd_updates_delayed_total[5m])))

### 3. Remote Write Metrics

- `prometheus:remote_write:samples_retried:rate5m`: This rule exposes a five-minute per-second rate from **prometheus_remote_storage_samples_retried_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, remote_name, url) (rate(prometheus_remote_storage_samples_retried_total[5m]))

- `prometheus:remote_write:samples_failed:rate5m`: This rule exposes a five-minute per-second rate from **prometheus_remote_storage_samples_failed_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, remote_name, url) (rate(prometheus_remote_storage_samples_failed_total[5m]))

- `prometheus:remote_write:lag_seconds`: Difference between the newest queued sample timestamp and the newest sent sample timestamp. It measures effective remote-write lag.
  > Expr: (max by (cluster, remote_name) (prometheus_remote_storage_queue_highest_timestamp_seconds)) - (max by (cluster, remote_name) (prometheus_remote_storage_queue_highest_sent_timestamp_seconds))

## Prometheus Operator Metrics

These rules summarize Prometheus Operator API interaction, reconcile health, and workqueue behavior.

### 1. Managed Resource Metrics

- `prometheus_operator:managed_resources_rejected_ratio`: This rule exposes the ratio from **prometheus_operator_managed_resources**. It is the failure-focused summary for this part of the component.
  > Expr: sum by (cluster, namespace, controller, resource) (max by (cluster, namespace, controller, resource, state) (prometheus_operator_managed_resources{state="rejected"})) / clamp_min(sum by (cluster, namespace, controller, resource) (max by (cluster, namespace, controller, resource, state) (prometheus_operator_managed_resources)), 1)

### 2. Kubernetes Client Metrics

- `prometheus_operator:kube_client_http_requests_errors:rate5m`: This rule exposes a five-minute per-second rate from **prometheus_operator_kubernetes_client_http_requests_total**. It is the failure-focused summary for this part of the component.
  > Expr: sum by (cluster, namespace) (rate(prometheus_operator_kubernetes_client_http_requests_total{status_code=~"[45].."}[5m]))

### 3. List And Sync Failure Metrics

- `prometheus_operator:list_operations_failed:rate5m`: This rule exposes a five-minute ratio from **prometheus_operator_list_operations_failed_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, namespace, controller) (rate(prometheus_operator_list_operations_failed_total{job="monitor-kube-prometheus-st-operator"}[5m]))

- `prometheus_operator:node_syncs_failed:rate5m`: This rule exposes a five-minute per-second rate from **prometheus_operator_node_syncs_failed_total**. It is the failure-focused summary for this part of the component.
  > Expr: sum by (cluster, namespace, resource) (rate(prometheus_operator_node_syncs_failed_total{job="monitor-kube-prometheus-st-operator"}[5m]))

### 4. Controller Health Metrics

- `prometheus_operator:not_ready`: Boolean-style rule that becomes `1` when the Operator has not been ready during the last five minutes.

  > Expr: max by (cluster, namespace, controller) (max_over_time(prometheus_operator_ready{job="monitor-kube-prometheus-st-operator"}[5m])) == bool 0

- `prometheus_operator:reconcile_errors:rate5m`: This rule exposes a five-minute per-second rate from **prometheus_operator_reconcile_errors_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, namespace, controller) (rate(prometheus_operator_reconcile_errors_total{job="monitor-kube-prometheus-st-operator"}[5m]))

- `prometheus_operator:status_update_errors:rate5m`: This rule exposes a five-minute per-second rate from **prometheus_operator_status_update_errors_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, namespace, controller) (rate(prometheus_operator_status_update_errors_total{job="monitor-kube-prometheus-st-operator"}[5m]))

- `prometheus_operator:sync_failed_objects`: This rule exposes the current level from **prometheus_operator_syncs**. It is the failure-focused summary for this part of the component.
  > Expr: max by (cluster, namespace, controller) (prometheus_operator_syncs{status="failed",job="monitor-kube-prometheus-st-operator"})

### Watch Metrics

- `prometheus_operator:watch_errors:ratio5m`: This rule exposes a five-minute ratio from **prometheus_operator_watch_operations_failed_total**, **prometheus_operator_watch_operations_total**. It is the failure-focused summary for this part of the component.
  > Expr: sum by (cluster, namespace, controller) (rate(prometheus_operator_watch_operations_failed_total{job="monitor-kube-prometheus-st-operator"}[5m])) / clamp_min(sum by (cluster, namespace, controller) (rate(prometheus_operator_watch_operations_total{job="monitor-kube-prometheus-st-operator"}[5m])), 1)

### Workqueue Metrics

- `prometheus_operator:workqueue_depth`: This rule exposes the current level from **prometheus_operator_workqueue_depth**. It is the compact operational summary for this part of the component.

  > Expr: max by (cluster, namespace, controller, name) (prometheus_operator_workqueue_depth{job="monitor-kube-prometheus-st-operator"})

- `prometheus_operator:workqueue_longest_running_seconds`: This rule exposes the current level from **prometheus_operator_workqueue_longest_running_processor_seconds**. It is the compact operational summary for this part of the component.

  > Expr: max by (cluster, namespace, controller, name) (prometheus_operator_workqueue_longest_running_processor_seconds{job="monitor-kube-prometheus-st-operator"})

- `prometheus_operator:workqueue_retries:rate5m`: This rule exposes a five-minute per-second rate from **prometheus_operator_workqueue_retries_total**. It is the compact operational summary for this part of the component.
  > Expr: sum by (cluster, namespace, controller, name) (rate(prometheus_operator_workqueue_retries_total{job="monitor-kube-prometheus-st-operator"}[5m]))

## CoreDNS Metrics

CoreDNS rules condense cache efficiency, DNS request quality, forwarding behavior, Kubernetes-plugin dependency health, and self-stability.

### 1. Cache Metrics

- `coredns:cache:req_rate5m`: This rule exposes a five-minute per-second rate from **coredns_cache_requests_total**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(coredns_cache_requests_total[5m]))

- `coredns:cache:hit_ratio5m`: This rule exposes a five-minute ratio from **coredns_cache_hits_total**, **coredns_cache_misses_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(coredns_cache_hits_total[5m])) / clamp_min(sum by (cluster, instance) (rate(coredns_cache_hits_total[5m])) + sum by (cluster, instance) (rate(coredns_cache_misses_total[5m])),1e-6)

- `coredns:cache:entries`: This rule exposes the current level from **coredns_cache_entries**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance, server) (coredns_cache_entries)

- `coredns:cache:counter_resets5m`: This rule exposes a five-minute count from **coredns_cache_requests_total**, **coredns_cache_hits_total**. It is the inventory-style summary for this part of the component.
  > Expr: sum by (cluster, instance, server) (resets(coredns_cache_requests_total[5m])) + sum by (cluster, instance, server) (resets(coredns_cache_hits_total[5m]))

### 2. DNS Request Metrics

- `coredns:dns:req_rate5m`: This rule exposes a five-minute per-second rate from **coredns_dns_requests_total**. It is the throughput summary for this part of the component.

  > Expr: sum by (cluster, instance, server, proto) (rate(coredns_dns_requests_total[5m]))

- `coredns:dns:rcode_error_ratio5m`: This rule exposes a five-minute ratio from **coredns_dns_responses_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, instance, server) (rate(coredns_dns_responses_total{rcode!="NOERROR", rcode!="NXDOMAIN"}[5m])) / clamp_min(sum by (cluster, instance, server) (rate(coredns_dns_responses_total[5m])), 1)

- `coredns:dns:latency_avg_5m`: This rule exposes a five-minute average from **coredns_dns_request_duration_seconds_sum**, **coredns_dns_request_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.
  > Expr: sum by (cluster, instance, server, zone) (rate(coredns_dns_request_duration_seconds_sum[5m])) / clamp_min(sum by (cluster, instance, server, zone) (rate(coredns_dns_request_duration_seconds_count[5m])), 1)

### 3. Forwarding Metrics

- `coredns:forward:healthcheck_broken_rate5m`: This rule exposes a five-minute per-second rate from **coredns_forward_healthcheck_broken_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(coredns_forward_healthcheck_broken_total[5m]))

- `coredns:forward:max_concurrent_rejects_rate5m`: This rule exposes a five-minute per-second rate from **coredns_forward_max_concurrent_rejects_total**. It is the failure-focused summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(coredns_forward_max_concurrent_rejects_total[5m]))

- `coredns:forward:upstream_latency_avg_5m`: This rule exposes a five-minute average from **coredns_proxy_request_duration_seconds_sum**, **coredns_proxy_request_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.
  > Expr: sum by (cluster, instance, proxy_name, to) (rate(coredns_proxy_request_duration_seconds_sum[5m])) / clamp_min(sum by (cluster, instance, proxy_name, to) (rate(coredns_proxy_request_duration_seconds_count[5m])), 1)

### 4. Health Metrics

- `coredns:health:fail_rate5m`: This rule exposes a five-minute per-second rate from **coredns_health_request_failures_total**. It is the compact operational summary for this part of the component.
  > Expr: sum by (cluster, instance) (rate(coredns_health_request_failures_total[5m]))

### 5. Kubernetes Plugin Metrics

- `coredns:k3s:apiserver_error_ratio5m`: This rule exposes a five-minute ratio from **coredns_kubernetes_rest_client_requests_total**. It is the failure-focused summary for this part of the component.

  > Expr: (sum by (cluster, instance) (rate(coredns_kubernetes_rest_client_requests_total{job="coredns"}[5m])) - sum by (cluster, instance) (rate(coredns_kubernetes_rest_client_requests_total{job="coredns", code=~"2.."}[5m]))) / clamp_min(sum by (cluster, instance) (rate(coredns_kubernetes_rest_client_requests_total{job="coredns"}[5m])),1)

- `coredns:k3s:apiserver_latency_avg5m`: This rule exposes a five-minute average from **coredns_kubernetes_rest_client_request_duration_seconds_sum**, **coredns_kubernetes_rest_client_request_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(coredns_kubernetes_rest_client_request_duration_seconds_sum[5m])) / clamp_min(sum by (cluster, instance) (rate(coredns_kubernetes_rest_client_request_duration_seconds_count[5m])), 1)

- `coredns:k3s:apiserver_rate_limiter_wait_avg5m`: This rule exposes a five-minute average from **coredns_kubernetes_rest_client_rate_limiter_duration_seconds_sum**, **coredns_kubernetes_rest_client_rate_limiter_duration_seconds_count**. It is the latency or waiting-time summary for this part of the component.

  > Expr: sum by (cluster, instance) (rate(coredns_kubernetes_rest_client_rate_limiter_duration_seconds_sum[5m])) / clamp_min(sum by (cluster, instance) (rate(coredns_kubernetes_rest_client_rate_limiter_duration_seconds_count[5m])), 1)

### Critical Event Metrics

- `coredns:critical_events:rate5m`: This rule exposes a five-minute per-second rate from **coredns_reload_failed_total**, **coredns_panics_total**. It is the compact operational summary for this part of the component.

  > Expr: sum by (cluster) (rate(coredns_reload_failed_total[5m]) + rate(coredns_panics_total[5m]))
