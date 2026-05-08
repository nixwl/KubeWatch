# Stage 2 Tools

`stage2-audit` performs reproducible quality audits on the retained dataset
subsets and writes the results as structured reports.

## Audited Subsets

- `node_48d`
- `kube_controlplane_103d`
- `pod_682d`

These subsets come from the raw metric exports and are paired with the aligned
labels produced by Stage 1.

## Python Scripts

### `audit_config.py`

- Defines input paths, output paths, the timestamp column, the expected sampling interval, and subset-specific settings.
- Maps each source CSV to its corresponding Stage 1 label file.

### `audit_main.py`

- Main entrypoint for Stage 2.
- Runs the missing-value, temporal, distribution, and label audit modules.
- Aggregates the results and writes the final Markdown report.

### `audit_utils.py`

- Provides common helpers for reading CSV files, filtering feature columns, joining subset paths, and writing figures or placeholder outputs.

### `audit_missing.py`

- Measures missing counts, missing ratios, and missing patterns.
- Produces files such as `missing_summary.csv`, `missing_pattern.csv`, and heatmaps.

### `audit_temporal.py`

- Audits sampling intervals, duplicate timestamps, and temporal gaps.
- Produces timestamp summaries, gap reports, and interval plots.

### `audit_distribution.py`

- Computes distribution statistics, constant-column checks, duplicate-column checks, and high-correlation checks.
- Produces correlation matrices and boxplot-style summaries.

### `audit_label.py`

- Audits label sparsity, event segments, and positive counts per feature.
- Produces label distribution plots and event tables.

### `audit_report.py`

- Assembles module outputs into `audit_report.md` and `audit_summary.csv`.
- Generates README-style summaries under the Stage 2 output tree.

## Outputs

Default output directory:

- `data/processed/02-dataset-purify/stage2-audit`

Main structure:

- `report/`
- `<subset>/missing/`
- `<subset>/temporal/`
- `<subset>/distribution/`
- `<subset>/label/`

## Direct Execution

```bash
python src/02-dataset-purify/tools/stage2-audit/audit_main.py
```
