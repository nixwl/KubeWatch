# Stage1 Split Scripts

This directory contains the PowerShell launcher for stage1 split generation.

## `process_split_by_system_gaps.sh`

Purpose:

- call `split_by_system_gaps.py`
- prefer the repository `.venv\Scripts\python.exe`
- default the stage1 output root to `data/processed/04-dataset-normal/stage1-split`

Default output files:

- `data/processed/04-dataset-normal/stage1-split/*.npy`
- `data/processed/04-dataset-normal/stage1-split/*_segments.csv`
- `data/processed/04-dataset-normal/stage1-split/*_split_metadata.json`
- `data/processed/04-dataset-normal/stage1-split/stage1_split_summary.csv`

Notes:

- the file extension is `.sh`, but the content is PowerShell
- raw inputs are resolved by the Python tool from `data/raw/04-dataset-normal`

Run:

```powershell
& .\src\04-dataset-normal\scripts\stage1-split\process_split_by_system_gaps.sh
```
