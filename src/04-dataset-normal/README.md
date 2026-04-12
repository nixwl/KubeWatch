# Dataset-Normal

This directory contains the dataset-normal preprocessing pipeline.

Current runtime data paths are repository-level paths:

- raw input: `data/raw/04-dataset-normal`
- processed output: `data/processed/04-dataset-normal`

## Main Components

- `check_csv_gaps.py`
  Inspect raw CSV files and generate gap reports.
- `tools/stage1-split/`
  Build `train / val / test` arrays and segment manifests from shared system gaps.
- `tools/stage2-normal/`
  Fit train-only scalers, normalize arrays, and build `val/test` label matrices.
- `scripts/`
  PowerShell launchers for the stage tools.

## Recommended Order

1. `check_csv_gaps.py`
2. `scripts/stage1-split/process_split_by_system_gaps.sh`
3. `scripts/stage2-normal/process_normal.sh`
4. `tools/stage2-normal/label.py`
5. `../build.py`

## Quick Start

```powershell
python .\src\04-dataset-normal\check_csv_gaps.py
& .\src\04-dataset-normal\scripts\stage1-split\process_split_by_system_gaps.sh
& .\src\04-dataset-normal\scripts\stage2-normal\process_normal.sh
python .\src\04-dataset-normal\tools\stage2-normal\label.py
python .\src\04-dataset-normal\build.py
```

## Related Docs

- [../README.md](../README.md)
- [tools/stage1-split/README.md](tools/stage1-split/README.md)
- [scripts/stage1-split/README.md](scripts/stage1-split/README.md)
- [tools/stage2-normal/README.md](tools/stage2-normal/README.md)
- [scripts/stage2-normal/README.md](scripts/stage2-normal/README.md)
