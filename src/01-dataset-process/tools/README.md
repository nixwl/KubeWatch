# Dataset Process Tools

This directory contains the Python tools used by the dataset processing
pipeline under `src/01-dataset-process/tools`.

## Stage Layout

The tools are organized by processing stage:

- `stage1_raw_to_aggregate/`
- `stage2_daily_refine/`
- `stage3_restruct/`

Processing model:

- Stage 1: transform one raw multi-table export into job-level and aggregate-level wide tables.
- Stage 2: aggregate hourly outputs into daily datasets, then align, clean, and refine them.
- Stage 3: reorganize and merge component-level daily outputs for downstream use.

## Stage 1: raw to aggregate

Directory:

- `src/01-dataset-process/tools/stage1_raw_to_aggregate/`

Recommended order:

1. `dataset_table_spilter.py`
2. job-specific processing scripts
3. `aggregate_process.py`
4. `collect_aggregated_csvs.py` when collection is required

Scripts:

- `dataset_table_spilter.py`: split the raw Flux multi-table CSV into `table_*.csv` files and route them into `jobs/<job>/`.
- `alerts_process.py`: clean and reshape alert data.
- `node-exporter_process.py`: clean node-exporter data and build node-wide outputs.
- `prometheus_process.py`: process Prometheus job data.
- `prometheus-operator_process.py`: process Prometheus Operator job data.
- `kubelet_process.py`: process kubelet data, including container-level flows.
- `kube-state-metrics_process.py`: split kube-state-metrics data by object type and build wide tables.
- `kube-scheduler_process.py`: process kube-scheduler data.
- `kube-proxy_process.py`: process kube-proxy data.
- `kube-controller-manager_process.py`: process kube-controller-manager data.
- `coredns_process.py`: process CoreDNS data.
- `apiserver_process.py`: process apiserver data.
- `aggregate_process.py`: build cleaned aggregate-level outputs.
- `collect_aggregated_csvs.py`: collect generated aggregate CSVs for inspection or export.

## Stage 2: aggregate to daily

Directory:

- `src/01-dataset-process/tools/stage2_daily_refine/`

Recommended order:

1. `extract_uid_mapping.py`
2. `aggregate_daily_dataset.py`
3. `preprocess_daily_dataset.py`

Scripts:

- `extract_uid_mapping.py`: extract UID-to-pod and workload mappings from raw `.csv.gz` archives under `data/raw/01-dataset-process/unaggregated-tables/` and write them into `data/raw/01-dataset-process/mapping/`.
- `aggregate_daily_dataset.py`: aggregate one day of hourly aggregate outputs into one daily dataset, align headers, and archive source aggregate folders.
- `preprocess_daily_dataset.py`: compute null ratios on daily CSVs, drop sparse columns, and fill protected metric families with type-aware rules.

## Stage 3: restructure

Directory:

- `src/01-dataset-process/tools/stage3_restruct/`

Scripts:

- `reorganize_component_daily.py`: copy daily CSVs into `component-daily/raw` and `component-daily/aggregate` trees grouped by `node`, `pod`, and `kube`.
- `merge_kube_component_daily.py`: merge related kube aggregate CSVs by `_time` and rename them into simpler component-level outputs such as `kube-prometheus.csv` and `kube-controlplane.csv`.
