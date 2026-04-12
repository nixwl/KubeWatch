# Stage2 Normal Tools

This directory contains the Python tools for stage2 normalization and label construction.

Current runtime data paths:

- raw input: `data/raw/04-dataset-normal`
- stage1 input: `data/processed/04-dataset-normal/stage1-split`
- stage2 output: `data/processed/04-dataset-normal/stage2-normal`

## `normal.py`

Purpose:

- read stage1 split arrays and segment manifests
- fit one train-only z-score scaler from `train_seg1 + train_seg2`
- normalize `train / val / test`
- keep `_time` unchanged
- copy split manifests into the stage2 output root

Default inputs:

- `data/processed/04-dataset-normal/stage1-split/*.npy`
- `data/processed/04-dataset-normal/stage1-split/*_segments.csv`
- `data/processed/04-dataset-normal/stage1-split/*_split_metadata.json`

Default outputs:

- `data/processed/04-dataset-normal/stage2-normal/*.npy`
- `data/processed/04-dataset-normal/stage2-normal/*_segments.csv`
- `data/processed/04-dataset-normal/stage2-normal/*_scaler.json`
- `data/processed/04-dataset-normal/stage2-normal/*_normal_metadata.json`
- `data/processed/04-dataset-normal/stage2-normal/stage2_normal_summary.csv`

Run:

```powershell
python .\src\04-dataset-normal\tools\stage2-normal\normal.py
```

## `label.py`

Purpose:

- build full-feature `val/test` label matrices from raw `*_labels.csv`
- reorder time-major labels into entity-major order where needed
- validate row and column alignment against the normalized feature arrays

Default inputs:

- `data/raw/04-dataset-normal/kube_pod_labels.csv`
- `data/raw/04-dataset-normal/node_labels.csv`
- `data/raw/04-dataset-normal/kube_controlplane_labels.csv`
- `data/processed/04-dataset-normal/stage1-split/*_split_metadata.json`
- `data/processed/04-dataset-normal/stage2-normal/*_{val,test}.npy`
- `data/processed/04-dataset-normal/stage2-normal/*_{val,test}_segments.csv`

Default outputs:

- `data/processed/04-dataset-normal/stage2-normal/*_val_labels.npy`
- `data/processed/04-dataset-normal/stage2-normal/*_test_labels.npy`
- `data/processed/04-dataset-normal/stage2-normal/*_label_metadata.json`
- `data/processed/04-dataset-normal/stage2-normal/stage2_label_summary.csv`

Run:

```powershell
python .\src\04-dataset-normal\tools\stage2-normal\label.py
```

## Loader Note

After `build.py`, the final arrays and labels live under `data/processed/04-dataset-normal`
and are consumed by [../../../../k3_dataset_loader.py](../../../../k3_dataset_loader.py).
