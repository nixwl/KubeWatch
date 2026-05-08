# Stage 4 Tools

`stage4-merge` merges injection windows with temporally overlapping retained
alerts and produces one row per matched injection window.

## Script

### `merge_windows.py`

- Reads `data/raw/03-dataset-labeling/label/inject_label_windows.csv`.
- Reads `data/processed/03-dataset-labeling/stage3-filter/filter_aligned_alerts.csv`.
- Reads `data/processed/03-dataset-labeling/stage1-analysis/inject_labels_summary.csv`.
- Reads `data/raw/03-dataset-labeling/label/prometheus_alert_metric_map.json`.
- Uses `data/raw/01-dataset-process/mapping` to resolve pod-related mappings.
- Uses `data/raw/03-dataset-labeling/data` to expand concrete raw metric columns.
- Keeps only injection windows that overlap at least one retained Stage 3 alert row.
- Merges observed alert types and expected alert types into one window-level output.

Outputs:

- `data/processed/03-dataset-labeling/stage4-merge/window_matches.csv`
- `data/processed/03-dataset-labeling/stage4-merge/window_matches_summary.csv`
