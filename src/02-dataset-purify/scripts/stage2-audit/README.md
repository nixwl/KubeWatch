# Stage 2 Launchers

This directory contains the bash launcher for the `stage2-audit` step.

## Script

### `run_stage2_audit.sh`

- Runs `tools/stage2-audit/audit_main.py`.
- Uses `audit_config.py` by default.
- Resolves the Python executable through the shared `script_config.sh` helper.

## Example

```bash
bash src/02-dataset-purify/scripts/stage2-audit/run_stage2_audit.sh
```
