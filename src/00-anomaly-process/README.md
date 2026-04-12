# Anomaly Process

This directory contains the end-to-end scripts that transform raw alert exports
and injection logs into anomaly windows, event tables, and alert intervals.

## Pipeline

### 00 `extract_alarm_range`

File: `00-extract_alarm_range.py`

Purpose:

- Read closed-loop alert exports under `data/raw/00-anomaly-process/Alertsnitch`.
- Build alert episode ranges from the source records.

Default output:

- `data/processed/00-anomaly-process/closed_loop_alerts_2026-02-05_labeled.csv`

Example:

```bash
python src/00-anomaly-process/00-extract_alarm_range.py \
  --output data/processed/00-anomaly-process/closed_loop_alerts_2026-02-05_labeled.csv
```

### 01 `map_alarm_to_metric`

File: `01-map_alarm_to_metric.py`

Purpose:

- Parse PrometheusRule files under `data/raw/00-anomaly-process/prometheusRole`.
- Map alert names to the metric families they affect.

Default outputs:

- `data/processed/00-anomaly-process/prometheus_alert_metric_map.json`
- `data/processed/00-anomaly-process/prometheus_alert_metric_map.csv`

Example:

```bash
python src/00-anomaly-process/01-map_alarm_to_metric.py \
  --rules-dir data/raw/00-anomaly-process/prometheusRole \
  --output-json data/processed/00-anomaly-process/prometheus_alert_metric_map.json \
  --output-csv data/processed/00-anomaly-process/prometheus_alert_metric_map.csv
```

### 02 `enrich_closed_loop_alerts_metrics`

File: `02-enrich_closed_loop_alerts_metrics.py`

Purpose:

- Join the labeled alert ranges from step 00 with the alert-to-metric map from step 01.
- Write the derived `impact_metrics` field back into the alert table.

Default output:

- `data/processed/00-anomaly-process/closed_loop_alerts_2026-02-05_labeled_with_metrics.csv`

Example:

```bash
python src/00-anomaly-process/02-enrich_closed_loop_alerts_metrics.py \
  --alerts-csv data/processed/00-anomaly-process/closed_loop_alerts_2026-02-05_labeled.csv \
  --map-json data/processed/00-anomaly-process/prometheus_alert_metric_map.json \
  --output-csv data/processed/00-anomaly-process/closed_loop_alerts_2026-02-05_labeled_with_metrics.csv
```

### 03 `parse_anormal_inject_logs`

File: `03-parse_anormal_inject_logs.py`

Purpose:

- Parse injection logs under `data/raw/00-anomaly-process/Anormal-Inject`.
- Build event-level anomaly records.

Default output:

- `data/processed/00-anomaly-process/inject_events_detailed.csv`

Example:

```bash
python src/00-anomaly-process/03-parse_anormal_inject_logs.py \
  --inject-root data/raw/00-anomaly-process/Anormal-Inject \
  --output-csv data/processed/00-anomaly-process/inject_events_detailed.csv
```

### 04 `build_inject_label_windows`

File: `04-build_inject_label_windows.py`

Purpose:

- Convert event-level injection records into labeling windows.
- Optionally merge overlapping windows before export.

Default output:

- `data/processed/00-anomaly-process/inject_label_windows.csv`

Example:

```bash
python src/00-anomaly-process/04-build_inject_label_windows.py \
  --events-csv data/processed/00-anomaly-process/inject_events_detailed.csv \
  --output-csv data/processed/00-anomaly-process/inject_label_windows.csv \
  --merge-overlap
```

### 05 `collect_anormal_metric_alerts`

File: `05-collect_anormal_metric_alerts.py`

Purpose:

- Read archived raw tables from the dataset source.
- Extract `producer_*_tables/jobs/alerts/**`.
- Aggregate same-day alert files into one daily alert directory.

Default output layout:

```text
data/raw/00-anomaly-process/AnormalMetric/
|-- 20260125/
|   `-- alerts/...
`-- 20260204/
    `-- alerts/...
```

Example:

```bash
python src/00-anomaly-process/05-collect_anormal_metric_alerts.py
```

Single-day example:

```bash
python src/00-anomaly-process/05-collect_anormal_metric_alerts.py \
  --dates 20260126
```

### 06 `build_closed_loop_alert_intervals`

File: `06-build_closed_loop_alert_intervals.py`

Purpose:

- Read daily alerts from `data/raw/00-anomaly-process/AnormalMetric/<YYYYMMDD>/alerts/**`.
- Treat both `pending` and `firing` as anomalous states.
- Use `ALERTS_FOR_STATE` to recover interval start times.
- Merge adjacent alert samples into closed-loop anomaly intervals.

Default output:

- `data/processed/00-anomaly-process/metric_alerts_intervals.csv`

Notes:

- The script first writes per-day interval files into `data/processed/00-anomaly-process/anormal_metric_alert_intervals/`.
- After merging all per-day files into `metric_alerts_intervals.csv`, it deletes the temporary interval directory.

Important fields:

- `for_state_start_time`
- `observed_start_time`
- `observed_end_time`
- `episode_start_time`
- `episode_end_time`
- `had_pending`
- `had_firing`
- `state_sequence`

Example:

```bash
python src/00-anomaly-process/06-build_closed_loop_alert_intervals.py
```

Single-day example:

```bash
python src/00-anomaly-process/06-build_closed_loop_alert_intervals.py \
  --dates 20260125
```
