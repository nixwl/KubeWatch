# Stage 1 Launchers

This directory contains the bash launcher for the `stage1-alert2timestamp`
step.

## Script

### `process_expand_inject_windows_to_labels.sh`

- Runs `tools/stage1-alert2timestamp/expand_inject_windows_to_labels.py`.
- Fills in default paths for the raw dataset root, window file, alert-to-metric map, UID mapping root, and output directory.
- Supports processing only selected daily folders.

## Examples

```bash
bash src/02-dataset-purify/scripts/stage1-alert2timestamp/process_expand_inject_windows_to_labels.sh
```

Selected daily folders:

```bash
bash src/02-dataset-purify/scripts/stage1-alert2timestamp/process_expand_inject_windows_to_labels.sh \
  --date-dirs 20260125-daily 20260126-daily
```
