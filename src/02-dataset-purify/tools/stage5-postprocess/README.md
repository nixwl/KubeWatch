# Stage 5 Tools

`stage5-postprocess` produces the final compact feature tables, vertically
concatenated outputs, and final labels used for downstream analysis.

## Python Scripts

### `postprocess_node.py`

- Reads `stage3-solver/node_36d`.
- Removes six selected node metrics.
- Writes `stage5-postprocess/node_30d`.

### `postprocess_kube_controlplane.py`

- Reads `stage3-solver/kube_controlplane_56d`.
- Keeps only the selected 24 control plane metrics.
- Writes `stage5-postprocess/kube_controlplane_24d`.

### `postprocess_pod.py`

- Reads `stage3-solver/kube_pod_17d`.
- Removes seven selected pod metrics.
- Writes `stage5-postprocess/kube_pod_10d`.

### `merge.py`

- Groups Stage 5 subsets by file path.
- Fills missing timestamps and writes `NULL` placeholders when needed.
- Builds vertically concatenated outputs and entity-range metadata for node and pod datasets.
- Moves final artifacts into `data/processed/02-dataset-purify/`.
- Normalizes and collects Stage 5 summary files.

### `labels.py`

- Collects the final labels produced under `stage1-alert2timestamp`.
- Aligns them to the column order of `kube_controlplane.csv`, `kube_pod_10d.csv`, and `node_30d.csv`.
- Writes the final label files into `data/processed/02-dataset-purify/`.

## Main Outputs

Under `data/processed/02-dataset-purify/`:

- `kube_controlplane.csv`
- `kube_controlplane_labels.csv`
- `kube_pod_10d.csv`
- `kube_pod_labels.csv`
- `kube_pod_vertical_entity_ranges.csv`
- `kube_pod_vertical_metadata.json`
- `node_30d.csv`
- `node_labels.csv`
- `node_vertical_entity_ranges.csv`
- `node_vertical_metadata.json`

Under `data/processed/02-dataset-purify/stage5-postprocess/`:

- `merge_global_summary.csv`
- `merge_global_metadata.json`
- `*_postprocess_column_actions.json`
- `*_postprocess_file_summary.csv`
- `*_merge_group_summary.csv`
- `*_merge_group_metadata.json`
