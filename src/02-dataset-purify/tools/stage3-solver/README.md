# Stage 3 Tools

`stage3-solver` turns the audited raw subsets into cleaned datasets that are
ready for analysis or modeling, and rebuilds the aligned label files.

## Data Sources

- Raw metric features: `data/raw/03-dataset-labeling/data`
- Audit rules and findings: `data/processed/02-dataset-purify/stage2-audit`
- Label source and rewrite target: `data/processed/02-dataset-purify/stage1-alert2timestamp`

## Python Scripts

### `solve_node.py`

- Reads the `node_48d` subset.
- Removes constant or duplicate columns identified in Stage 2.
- Interpolates selected random-missing columns within allowed segments.
- Writes `stage3-solver/node_36d`.

### `solve_kube_controlplane.py`

- Reads the `kube_controlplane_103d` subset.
- Removes constant columns and PVC-related columns.
- Interpolates selected random-missing columns.
- Writes `stage3-solver/kube_controlplane_56d`.

### `solve_pod.py`

- Reads the raw `kube-pod.csv`.
- Splits the source into per-pod files.
- Removes selected always-zero metrics.
- Fills selected utilization metrics with default strategies.
- Writes `stage3-solver/kube_pod_17d`.

### `build_stage3_labels.py`

- Reads the Stage 1 label matrices and the cleaned Stage 3 datasets.
- Rebuilds label files so the column layout and file layout match the Stage 3 outputs exactly.
- Writes the rebuilt labels back under `stage1-alert2timestamp`.

## Outputs

- `data/processed/02-dataset-purify/stage3-solver/node_36d`
- `data/processed/02-dataset-purify/stage3-solver/kube_controlplane_56d`
- `data/processed/02-dataset-purify/stage3-solver/kube_pod_17d`
- `data/processed/02-dataset-purify/stage1-alert2timestamp/build_metadata.json`
- `data/processed/02-dataset-purify/stage1-alert2timestamp/label_build_summary.csv`

## Direct Execution

```bash
python src/02-dataset-purify/tools/stage3-solver/solve_node.py
python src/02-dataset-purify/tools/stage3-solver/solve_kube_controlplane.py
python src/02-dataset-purify/tools/stage3-solver/solve_pod.py
python src/02-dataset-purify/tools/stage3-solver/build_stage3_labels.py
```
