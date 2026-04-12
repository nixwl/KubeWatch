# Stage 5 Launchers

This directory contains the bash launchers for the `stage5-postprocess` step.

## Scripts

### `run_postprocess_node.sh`

- Runs `tools/stage5-postprocess/postprocess_node.py`.
- Produces `data/processed/02-dataset-purify/stage5-postprocess/node_30d`.

### `run_postprocess_kube_controlplane.sh`

- Runs `tools/stage5-postprocess/postprocess_kube_controlplane.py`.
- Produces `data/processed/02-dataset-purify/stage5-postprocess/kube_controlplane_24d`.

### `run_postprocess_pod.sh`

- Runs `tools/stage5-postprocess/postprocess_pod.py`.
- Produces `data/processed/02-dataset-purify/stage5-postprocess/kube_pod_10d`.

### `run_merge_stage5.sh`

- Runs `tools/stage5-postprocess/merge.py`.
- Merges same-path outputs, builds vertically concatenated datasets, and moves final artifacts into the processed root.

### `run_build_labels.sh`

- Runs `tools/stage5-postprocess/labels.py`.
- Builds the final label files such as `kube_controlplane_labels.csv`, `kube_pod_labels.csv`, and `node_labels.csv`.

## Recommended Order

```bash
bash src/02-dataset-purify/scripts/stage5-postprocess/run_postprocess_node.sh
bash src/02-dataset-purify/scripts/stage5-postprocess/run_postprocess_kube_controlplane.sh
bash src/02-dataset-purify/scripts/stage5-postprocess/run_postprocess_pod.sh
bash src/02-dataset-purify/scripts/stage5-postprocess/run_merge_stage5.sh
bash src/02-dataset-purify/scripts/stage5-postprocess/run_build_labels.sh
```
