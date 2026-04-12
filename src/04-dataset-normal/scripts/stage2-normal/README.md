# Stage2 Normal Scripts

This directory contains the PowerShell launcher for stage2 normalization.

## `process_normal.sh`

Purpose:

- call `normal.py`
- prefer the repository `.venv\Scripts\python.exe`
- default the stage1 input root to `data/processed/04-dataset-normal/stage1-split`
- default the stage2 output root to `data/processed/04-dataset-normal/stage2-normal`

Default output files:

- `data/processed/04-dataset-normal/stage2-normal/*.npy`
- `data/processed/04-dataset-normal/stage2-normal/*_segments.csv`
- `data/processed/04-dataset-normal/stage2-normal/*_scaler.json`
- `data/processed/04-dataset-normal/stage2-normal/*_normal_metadata.json`
- `data/processed/04-dataset-normal/stage2-normal/stage2_normal_summary.csv`

Notes:

- the file extension is `.sh`, but the content is PowerShell
- `label.py` is still executed separately after normalization

Run:

```powershell
& .\src\04-dataset-normal\scripts\stage2-normal\process_normal.sh
```
