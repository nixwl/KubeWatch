# Stage 1 Launchers

This directory contains the bash launchers for the `stage1-analysis` step.

## Scripts

### `process_analyze_closed_loop_alerts.sh`

- Runs `tools/stage1-analysis/analyze_closed_loop_alerts.py`.
- Defaults to `data/raw/03-dataset-labeling/label/closed_loop_alerts_2026-02-05_labeled.csv`.
- Writes outputs into `data/processed/03-dataset-labeling/stage1-analysis`.

### `process_analyze_inject_labels.sh`

- Runs `tools/stage1-analysis/analyze_inject_labels.py`.
- Defaults to the injection event, window, and alert-map files under `data/raw/03-dataset-labeling/label`.
- Writes outputs into `data/processed/03-dataset-labeling/stage1-analysis`.

### `process_analyze_metric_alerts.sh`

- Runs `tools/stage1-analysis/analyze_metric_alerts.py`.
- Defaults to `data/raw/03-dataset-labeling/label/metric_alerts_intervals.csv`.
- Writes outputs into `data/processed/03-dataset-labeling/stage1-analysis`.

## Examples

```bash
bash src/03-dataset-labeling/scripts/stage1-analysis/process_analyze_closed_loop_alerts.sh
bash src/03-dataset-labeling/scripts/stage1-analysis/process_analyze_inject_labels.sh
bash src/03-dataset-labeling/scripts/stage1-analysis/process_analyze_metric_alerts.sh
```
