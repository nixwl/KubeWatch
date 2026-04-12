# Stage 4 Launchers

This directory contains the bash launcher for the `stage4-merge` step.

## Script

### `process_merge_windows.sh`

- Runs `tools/stage4-merge/merge_windows.py`.
- Uses `data/raw/03-dataset-labeling/label/inject_label_windows.csv` as the default injection-window input.
- Uses `data/processed/03-dataset-labeling/stage3-filter/filter_aligned_alerts.csv` as the default aligned-alert input.
- Writes `window_matches.csv` and `window_matches_summary.csv` into `data/processed/03-dataset-labeling/stage4-merge`.

## Example

```bash
bash src/03-dataset-labeling/scripts/stage4-merge/process_merge_windows.sh
```
