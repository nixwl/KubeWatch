# Dataset Labeling

`src/03-dataset-labeling` contains the scripts and tools that transform raw
label artifacts into aligned, filtered, and merged window-level outputs.

## Layout

- `tools/`: Python implementations grouped by processing stage.
- `scripts/`: bash launchers grouped by processing stage.

## Data Layout

Default inputs:

- `data/raw/03-dataset-labeling/label`
- `data/raw/03-dataset-labeling/data`

Default outputs:

- `data/processed/03-dataset-labeling/stage1-analysis`
- `data/processed/03-dataset-labeling/stage2-align`
- `data/processed/03-dataset-labeling/stage3-filter`
- `data/processed/03-dataset-labeling/stage4-merge`

Related external inputs:

- `data/raw/01-dataset-process/mapping`

## Pipeline

Recommended execution order:

1. `stage1-analysis`
2. `stage2-align`
3. `stage3-filter`
4. `stage4-merge`

## Stage Overview

### Stage 1 Analysis

Purpose:

- normalize `closed_loop_alerts`
- normalize injection labels
- summarize `metric_alerts_intervals`

Main outputs:

- `closed_loop_alerts_info.csv`
- `closed_loop_alerts_summary.csv`
- `inject_labels_info.csv`
- `inject_labels_summary.csv`
- `metric_alerts_info.csv`
- `metric_alerts_summary.csv`

### Stage 2 Align

Purpose:

- align `closed_loop_alerts_info.csv` onto `metric_alerts_info.csv`
- replace `affect_metrics` in aligned rows with the full mapped `impact_metrics`

Main outputs:

- `closed_aligned_alerts.csv`
- `closed_aligned_alerts_align_summary.csv`
- `closed_aligned_alerts_rejected_closed_loop.csv`
- `closed_aligned_alerts_metric_map_summary.csv`
- `closed_aligned_alerts_missing_alerts_summary.csv`

### Stage 3 Filter

Purpose:

- drop alerts that ended before the first injection cutoff
- drop zero-duration rows
- write `anormal_category` into the retained outputs

Main outputs:

- `filter_aligned_alerts.csv`
- `filter_aligned_dropped.csv`
- `filter_aligned_summary.csv`

### Stage 4 Merge

Purpose:

- use `inject_label_windows.csv` as the window baseline
- merge temporally overlapping rows from `filter_aligned_alerts.csv`
- combine observed alert types with expected alert types derived from injection metadata

Main outputs:

- `window_matches.csv`
- `window_matches_summary.csv`

## Entrypoints

- [scripts/stage1-analysis/README.md](d:\Repo\KubeWatch\src\03-dataset-labeling\scripts\stage1-analysis\README.md)
- [tools/stage1-analysis/README.md](d:\Repo\KubeWatch\src\03-dataset-labeling\tools\stage1-analysis\README.md)
- [scripts/stage2-align/README.md](d:\Repo\KubeWatch\src\03-dataset-labeling\scripts\stage2-align\README.md)
- [tools/stage2-align/README.md](d:\Repo\KubeWatch\src\03-dataset-labeling\tools\stage2-align\README.md)
- [scripts/stage3-filter/README.md](d:\Repo\KubeWatch\src\03-dataset-labeling\scripts\stage3-filter\README.md)
- [tools/stage3-filter/README.md](d:\Repo\KubeWatch\src\03-dataset-labeling\tools\stage3-filter\README.md)
- [scripts/stage4-merge/README.md](d:\Repo\KubeWatch\src\03-dataset-labeling\scripts\stage4-merge\README.md)
- [tools/stage4-merge/README.md](d:\Repo\KubeWatch\src\03-dataset-labeling\tools\stage4-merge\README.md)
