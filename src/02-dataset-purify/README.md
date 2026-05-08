# Dataset Purify

`src/02-dataset-purify` contains the scripts and tools used to clean, audit,
analyze, and finalize the purified dataset.

## Structure

- [`tools/`](./tools): Python tools grouped by processing stage.
- [`scripts/`](./scripts): bash launchers grouped by processing stage.

## Stages

- `stage1-alert2timestamp`: project anomaly windows back onto the original metric timestamps and build label matrices.
- `stage2-audit`: audit missing values, temporal continuity, distributions, and label quality.
- `stage3-solver`: clean stage-audited subsets, interpolate selected gaps, split pod data, and rebuild aligned labels.
- `stage4-analysis`: run univariate, multivariate, and feature-importance analysis.
- `stage5-postprocess`: trim final feature sets, merge outputs, build vertically concatenated datasets, and publish final labels.

## Usage

- Prefer the launcher scripts under `src/02-dataset-purify/scripts/<stage>/`.
- Each stage has its own `README.md` under both `tools/` and `scripts/`.
- Default inputs are read from `data/raw/03-dataset-labeling`.
- Default outputs are written to `data/processed/02-dataset-purify`.
