# Stage 4 Launchers

This directory contains the bash launchers for the `stage4-analysis` step.

## Scripts

### `run_basic_univariate_analysis.sh`

- Runs `tools/stage4-analysis/run_basic_univariate_analysis.py`.
- Supports optional skip flags for basic statistics, event-window analysis, temporal analysis, and split filtering.

### `run_multivariate_analysis.sh`

- Runs `tools/stage4-analysis/run_multivariate_analysis.py`.

### `run_feature_importance_analysis.sh`

- Runs `tools/stage4-analysis/run_feature_importance_analysis.py`.

## Examples

```bash
bash src/02-dataset-purify/scripts/stage4-analysis/run_basic_univariate_analysis.sh
bash src/02-dataset-purify/scripts/stage4-analysis/run_multivariate_analysis.sh
bash src/02-dataset-purify/scripts/stage4-analysis/run_feature_importance_analysis.sh
```
