# Stage 4 Tools

`stage4-analysis` runs statistical analysis on the cleaned Stage 3 datasets and
their aligned labels.

## Inputs

- Feature datasets: `data/processed/02-dataset-purify/stage3-solver`
- Label datasets: `data/processed/02-dataset-purify/stage1-alert2timestamp`

## Python Scripts

### `run_basic_univariate_analysis.py`

- Computes core univariate statistics.
- Compares normal and anomalous distributions.
- Measures event-window effects.
- Computes time-dependence features such as ACF, PACF, and related segment-level metrics.

### `run_multivariate_analysis.py`

- Computes Pearson, Spearman, mutual information, and other multivariate dependence metrics.
- Identifies strongly dependent feature pairs.
- Builds correlated feature groups and candidate representative features.

### `run_feature_importance_analysis.py`

- Trains per-file anomaly classification models, typically based on random forests.
- Exports conventional feature importance, SHAP importance, and model metrics.

## Outputs

- `data/processed/02-dataset-purify/stage4-analysis/univariate_analysis`
- `data/processed/02-dataset-purify/stage4-analysis/multivariate_analysis`
- `data/processed/02-dataset-purify/stage4-analysis/feature_importance_analysis`

## Direct Execution

```bash
python src/02-dataset-purify/tools/stage4-analysis/run_basic_univariate_analysis.py
python src/02-dataset-purify/tools/stage4-analysis/run_multivariate_analysis.py
python src/02-dataset-purify/tools/stage4-analysis/run_feature_importance_analysis.py
```
