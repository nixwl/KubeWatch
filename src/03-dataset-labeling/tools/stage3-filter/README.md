# Stage 3 Tools

`stage3-filter` removes unwanted aligned alerts and writes coarse anomaly
categories for the retained rows.

## Scripts

### `filter_aligned_alerts.py`

- Reads `data/processed/03-dataset-labeling/stage2-align/closed_aligned_alerts.csv`.
- Drops rows that end before the first injection cutoff.
- Drops zero-duration rows.
- Writes `anormal_category` directly into the retained output.

Outputs:

- `data/processed/03-dataset-labeling/stage3-filter/filter_aligned_alerts.csv`
- `data/processed/03-dataset-labeling/stage3-filter/filter_aligned_dropped.csv`
- `data/processed/03-dataset-labeling/stage3-filter/filter_aligned_summary.csv`

### `classify_filter_aligned_alerts.py`

- Reads `filter_aligned_alerts.csv`.
- Rebuilds a categorized export, a category summary, and per-category split files.
- Keeps the category-only export path available as an optional helper.

Outputs:

- `data/processed/03-dataset-labeling/stage3-filter/filter_aligned_alerts_categorized.csv`
- `data/processed/03-dataset-labeling/stage3-filter/filter_aligned_category_summary.csv`
- `data/processed/03-dataset-labeling/stage3-filter/filter_aligned_by_category/`
