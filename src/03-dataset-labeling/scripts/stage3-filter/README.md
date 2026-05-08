# Stage 3 Launchers

This directory contains the bash launchers for the `stage3-filter` step.

## Scripts

### `process_filter_aligned_alerts.sh`

- Runs `tools/stage3-filter/filter_aligned_alerts.py`.
- Drops rows before the first injection cutoff and removes zero-duration intervals.
- Writes retained rows, dropped rows, and summary outputs into `data/processed/03-dataset-labeling/stage3-filter`.

### `process_classify_filter_aligned_alerts.sh`

- Runs `tools/stage3-filter/classify_filter_aligned_alerts.py`.
- Rebuilds category-oriented exports from the retained Stage 3 CSV.
- Writes category summaries and per-category files into `data/processed/03-dataset-labeling/stage3-filter`.

## Recommended Order

```bash
bash src/03-dataset-labeling/scripts/stage3-filter/process_filter_aligned_alerts.sh
bash src/03-dataset-labeling/scripts/stage3-filter/process_classify_filter_aligned_alerts.sh
```
