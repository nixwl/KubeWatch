# Stage 2 Tools

`stage2-align` merges the Stage 1 metric-alert view with the Stage 1
closed-loop alert view, then replaces incomplete metric lists with the full
mapped `impact_metrics`.

## Scripts

### `align_metric_closed_alerts.py`

- Normalizes Stage 1 times into UTC.
- Uses `metric_alerts_info.csv` as the base table.
- Merges compatible `closed_loop_alerts_info.csv` rows into the metric-alert intervals.
- Adds unmatched but valid closed-loop rows as standalone outputs when required.
- Builds the `closed_aligned_alerts` output set.

Default inputs:

- `data/processed/03-dataset-labeling/stage1-analysis/metric_alerts_info.csv`
- `data/processed/03-dataset-labeling/stage1-analysis/closed_loop_alerts_info.csv`

Default outputs:

- `data/processed/03-dataset-labeling/stage2-align/closed_aligned_alerts.csv`
- `data/processed/03-dataset-labeling/stage2-align/closed_aligned_alerts_rejected_closed_loop.csv`
- `data/processed/03-dataset-labeling/stage2-align/closed_aligned_alerts_align_summary.csv`

### `map_metric_closed_affect_metrics.py`

- Reads `closed_aligned_alerts.csv`.
- Reads `data/raw/03-dataset-labeling/label/prometheus_alert_metric_map.json`.
- Replaces `affect_metrics` with the full mapped `impact_metrics` when the alert name is known.
- Writes summary outputs for mapped and missing alert names.

Default outputs:

- `data/processed/03-dataset-labeling/stage2-align/closed_aligned_alerts.csv`
- `data/processed/03-dataset-labeling/stage2-align/closed_aligned_alerts_metric_map_summary.csv`
- `data/processed/03-dataset-labeling/stage2-align/closed_aligned_alerts_missing_alerts_summary.csv`
