# Stage 1 Tools

`stage1-alert2timestamp` projects the final anomaly windows back onto the
original metric timestamps and builds file-level `0/1` label matrices.

## Inputs

- Raw metric root: `data/raw/03-dataset-labeling/data`
- Matched window file: `data/raw/03-dataset-labeling/label/window_matches.csv`
- Alert-to-metric map: `data/raw/03-dataset-labeling/label/prometheus_alert_metric_map.json`
- Hourly UID mapping root: `data/raw/01-dataset-process/mapping`

## Python Script

### `expand_inject_windows_to_labels.py`

- Reads the matched anomaly windows from `window_matches.csv`.
- Matches windows against the real `node`, `kube`, and `pod` file structure instead of applying coarse global labels.
- Aligns windows to UTC second-level boundaries before projecting them onto the original `_time` axis.
- Writes `0/1` label files with the same row and column structure as the source CSV files.
- Produces file summaries, window summaries, and run metadata.

## Outputs

Default output directory:

- `data/processed/02-dataset-purify/stage1-alert2timestamp`

Main outputs:

- `node_36d/`
- `kube_controlplane_56d/`
- `kube_pod_17d/`
- `label_file_summary.csv`
- `window_label_summary.csv`
- `run_metadata.json`
- `build_metadata.json`
- `label_build_summary.csv`

The last two files are appended later by Stage 3 when labels are rebuilt
against the cleaned datasets.

## Direct Execution

```bash
python src/02-dataset-purify/tools/stage1-alert2timestamp/expand_inject_windows_to_labels.py
```

Selected daily folders:

```bash
python src/02-dataset-purify/tools/stage1-alert2timestamp/expand_inject_windows_to_labels.py \
  --date-dirs 20260125-daily 20260126-daily
```
