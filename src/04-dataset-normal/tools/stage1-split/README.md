# Stage1 Split Tools

This directory contains the Python tools for stage1 dataset splitting.

Current runtime data paths:

- raw input: `data/raw/04-dataset-normal`
- processed output: `data/processed/04-dataset-normal`

## `split_by_system_gaps.py`

Purpose:

- read raw metric CSV files and the precomputed `gap_*.csv` reports
- detect the two shared system gaps for each dataset
- produce `train / val / test` arrays
- write split segment manifests and split metadata

Default inputs:

- `data/raw/04-dataset-normal/kube_pod_10d.csv`
- `data/raw/04-dataset-normal/node_30d.csv`
- `data/raw/04-dataset-normal/kube_controlplane.csv`
- `data/processed/04-dataset-normal/gap_pod.csv`
- `data/processed/04-dataset-normal/gap_node.csv`
- `data/processed/04-dataset-normal/gap_kube_controllplane.csv`

Default outputs:

- `data/processed/04-dataset-normal/stage1-split/*.npy`
- `data/processed/04-dataset-normal/stage1-split/*_segments.csv`
- `data/processed/04-dataset-normal/stage1-split/*_split_metadata.json`
- `data/processed/04-dataset-normal/stage1-split/stage1_split_summary.csv`

Run:

```powershell
python .\src\04-dataset-normal\tools\stage1-split\split_by_system_gaps.py
```

## `verify_split_segments.py`

Purpose:

- verify that `*_segments.csv` matches the saved split arrays
- verify row ranges, time bounds, and gap annotations
- report any unmarked contiguous all-NaN runs

Default inputs:

- `data/processed/04-dataset-normal/stage1-split/*.npy`
- `data/processed/04-dataset-normal/stage1-split/*_segments.csv`
- `data/processed/04-dataset-normal/stage1-split/*_split_metadata.json`

Default outputs:

- `data/processed/04-dataset-normal/stage1-split/verification/segment_manifest_verification.csv`
- `data/processed/04-dataset-normal/stage1-split/verification/unmarked_all_nan_runs.csv`

Run:

```powershell
python .\src\04-dataset-normal\tools\stage1-split\verify_split_segments.py
```
