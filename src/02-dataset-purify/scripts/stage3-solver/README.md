# Stage 3 Launchers

This directory contains the bash launchers for the `stage3-solver` step.

## Scripts

### `run_solve_node.sh`

- Runs `tools/stage3-solver/solve_node.py`.
- Produces `data/processed/02-dataset-purify/stage3-solver/node_36d`.

### `run_solve_kube_controlplane.sh`

- Runs `tools/stage3-solver/solve_kube_controlplane.py`.
- Produces `data/processed/02-dataset-purify/stage3-solver/kube_controlplane_56d`.

### `run_solve_pod.sh`

- Runs `tools/stage3-solver/solve_pod.py`.
- Produces `data/processed/02-dataset-purify/stage3-solver/kube_pod_17d`.

### `run_build_stage3_labels.sh`

- Runs `tools/stage3-solver/build_stage3_labels.py`.
- Rebuilds label files aligned to the Stage 3 outputs.

## Recommended Order

```bash
bash src/02-dataset-purify/scripts/stage3-solver/run_solve_node.sh
bash src/02-dataset-purify/scripts/stage3-solver/run_solve_kube_controlplane.sh
bash src/02-dataset-purify/scripts/stage3-solver/run_solve_pod.sh
bash src/02-dataset-purify/scripts/stage3-solver/run_build_stage3_labels.sh
```
