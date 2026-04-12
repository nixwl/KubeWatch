# Stage 2 Launchers

This directory contains the bash launchers for the `stage2-align` step.

## Scripts

### `process_align_metric_closed_alerts.sh`

- Runs `tools/stage2-align/align_metric_closed_alerts.py`.
- Uses `metric_alerts_info.csv` and `closed_loop_alerts_info.csv` from Stage 1 by default.
- Writes aligned outputs into `data/processed/03-dataset-labeling/stage2-align`.

### `process_map_metric_closed_affect_metrics.sh`

- Runs `tools/stage2-align/map_metric_closed_affect_metrics.py`.
- Replaces `affect_metrics` in `closed_aligned_alerts.csv` with the full mapped `impact_metrics`.
- Writes the updated CSV and the mapping summaries into `data/processed/03-dataset-labeling/stage2-align`.

## Recommended Order

```bash
bash src/03-dataset-labeling/scripts/stage2-align/process_align_metric_closed_alerts.sh
bash src/03-dataset-labeling/scripts/stage2-align/process_map_metric_closed_affect_metrics.sh
```
