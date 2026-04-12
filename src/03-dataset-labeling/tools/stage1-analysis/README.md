# Stage 1 Tools

`stage1-analysis` converts raw label inputs into simplified event-level tables
and compact summary tables.

## Inputs

- `data/raw/03-dataset-labeling/label/closed_loop_alerts_2026-02-05_labeled.csv`
- `data/raw/03-dataset-labeling/label/inject_events_detailed.csv`
- `data/raw/03-dataset-labeling/label/inject_label_windows.csv`
- `data/raw/03-dataset-labeling/label/metric_alerts_intervals.csv`
- `data/raw/03-dataset-labeling/label/prometheus_alert_metric_map.json`

## Scripts

### `analyze_closed_loop_alerts.py`

- Cleans and normalizes closed-loop alert rows.
- Builds `closed_loop_alerts_info.csv` and `closed_loop_alerts_summary.csv`.

### `analyze_inject_labels.py`

- Converts injection events and windows into simplified Stage 1 views.
- Builds `inject_labels_info.csv` and `inject_labels_summary.csv`.

### `analyze_metric_alerts.py`

- Simplifies metric alert intervals into event-level and summary outputs.
- Builds `metric_alerts_info.csv` and `metric_alerts_summary.csv`.

## Outputs

- `data/processed/03-dataset-labeling/stage1-analysis/closed_loop_alerts_info.csv`
- `data/processed/03-dataset-labeling/stage1-analysis/closed_loop_alerts_summary.csv`
- `data/processed/03-dataset-labeling/stage1-analysis/inject_labels_info.csv`
- `data/processed/03-dataset-labeling/stage1-analysis/inject_labels_summary.csv`
- `data/processed/03-dataset-labeling/stage1-analysis/metric_alerts_info.csv`
- `data/processed/03-dataset-labeling/stage1-analysis/metric_alerts_summary.csv`
