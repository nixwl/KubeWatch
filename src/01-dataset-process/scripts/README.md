# Dataset Process Scripts

This directory contains the launcher scripts for the dataset processing
pipeline under `src/01-dataset-process/scripts`.

## Layout

- `script_config.sh`: shared bash configuration used by all `.sh` entrypoints.
- `script_config.ps1`: retained PowerShell configuration for legacy usage.
- `step/`: single-stage launchers for local reruns and debugging.
- `onekey/`: batch and one-click wrappers.
- `logs/`: execution logs such as mismatch reports and preprocessing logs.

## Shared Configuration

### `script_config.sh`

Purpose:

- Resolve repository-relative default paths.
- Define the default input root `data/raw/01-dataset-process`.
- Define the default output root `data/processed/01-dataset-process`.
- Expose shared helpers such as `get_k3_job_dir` and `invoke_k3_python`.

Important variables:

- `K3RawRootDir`
- `K3ArchivesRoot`
- `K3UnzipRoot`
- `K3MappingRoot`
- `K3ProcessedRootDir`
- `K3DatasetBaseName`
- `K3SourceCsvPath`
- `K3DatasetTablesDir`
- `K3CollectedOutputDir`
- `K3AggregateDir`

## Stage 1 Scripts

Directories:

- `step/stage1_raw_to_aggregate/`
- `onekey/stage1_raw_to_aggregate/`

Recommended order:

1. `run_table_spilter.sh`
2. job-specific processing scripts
3. `run_aggregate_process.sh`
4. collection scripts when needed

### `step/stage1_raw_to_aggregate/`

- `run_table_spilter.sh`: split one raw multi-table CSV and route outputs by job.
- `run_alerts_process.sh`: process alert tables.
- `run_node-exporter_process.sh`: process node-exporter tables.
- `run_prometheus_process.sh`: process Prometheus tables.
- `run_prometheus-operator_process.sh`: process Prometheus Operator tables.
- `run_kubelet_process.sh`: process kubelet tables, including container data.
- `run_kube-state-metrics_process.sh`: process kube-state-metrics tables.
- `run_kube-scheduler_process.sh`: process kube-scheduler tables.
- `run_kube-proxy_process.sh`: process kube-proxy tables.
- `run_kube-controller-manager_process.sh`: process kube-controller-manager tables.
- `run_coredns_process.sh`: process CoreDNS tables.
- `run_apiserver_process.sh`: process apiserver tables.
- `run_aggregate_process.sh`: build aggregate-level outputs.

### `onekey/stage1_raw_to_aggregate/`

- `run_rebuild_processed_no_aggregate.sh`: rebuild Stage 1 outputs except aggregate outputs.
- `run_rebuild_processed_all.sh`: rebuild all Stage 1 outputs, including aggregate outputs.
- `run_collect_aggregated_csvs.sh`: collect generated aggregate CSVs.
- `run_batch_onekey.sh`: run one selected Stage 1 launcher across multiple datasets.
- `run_batch_collect_aggregated_csvs.sh`: batch collect aggregate CSVs across datasets.

## Stage 2 Scripts

Directories:

- `step/stage2_daily_refine/`
- `onekey/stage2_daily_refine/`

Recommended order:

1. `process_extract_uid_mapping.sh`
2. `process_aggregate_daily_dataset.sh`
3. `process_preprocess_daily_dataset.sh`

### `step/stage2_daily_refine/`

- `process_extract_uid_mapping.sh`: run `extract_uid_mapping.py`, read `.csv.gz` archives from `data/raw/01-dataset-process/unaggregated-tables/`, and build UID mapping files under `data/raw/01-dataset-process/mapping/`.
- `process_aggregate_daily_dataset.sh`: run `aggregate_daily_dataset.py`, build `data/processed/01-dataset-process/daily/<date>-daily`, and archive hourly aggregate roots.
- `process_preprocess_daily_dataset.sh`: run `preprocess_daily_dataset.py` to drop sparse columns and fill protected metrics.

### `onekey/stage2_daily_refine/`

- `run_batch_process_extract_uid_mapping.sh`: batch run UID mapping extraction with optional range control.

## Stage 3 Scripts

Directory:

- `step/stage3_restruct/`

Scripts:

- `process_reorganize_component_daily.sh`: run `reorganize_component_daily.py` to copy daily CSVs into `component-daily/raw` and `component-daily/aggregate` folders grouped by `node`, `pod`, and `kube`.
- `process_merge_kube_component_daily.sh`: run `merge_kube_component_daily.py` to merge and rename aggregate kube component files such as Prometheus-related control plane CSVs.

## Logs

Typical log content:

- cross-day mismatch reports
- per-day mismatch folders
- preprocessing dry-run and apply logs
- null-ratio reports

Common files:

- `cross_day_mismatch.log`
- `<date>-aggregate_mismatch/...`
- `preprocess_daily_dataset_*.log`

## Recommended Entrypoints

Stage 1 full rebuild:

```bash
bash src/01-dataset-process/scripts/onekey/stage1_raw_to_aggregate/run_rebuild_processed_all.sh
```

Stage 2 and Stage 3 daily pipeline:

```bash
bash src/01-dataset-process/scripts/step/stage2_daily_refine/process_extract_uid_mapping.sh
bash src/01-dataset-process/scripts/step/stage2_daily_refine/process_aggregate_daily_dataset.sh
bash src/01-dataset-process/scripts/step/stage2_daily_refine/process_preprocess_daily_dataset.sh
bash src/01-dataset-process/scripts/step/stage3_restruct/process_reorganize_component_daily.sh
bash src/01-dataset-process/scripts/step/stage3_restruct/process_merge_kube_component_daily.sh
```
