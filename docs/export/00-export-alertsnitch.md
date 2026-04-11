# AlertSnitch Persistent Alert Data Export

This document describes how to export AlertSnitch data stored in MySQL.

## Scope

The export workflow produces:

- Full table-level TSV dumps (for backup and auditing)
- A lifecycle summary TSV: `closed_loop_alerts.tsv` (for analysis)
- Optional CSV conversion for BI/Excel use

## Data Model Overview

AlertSnitch persists Alertmanager webhook events with a "main table + key/value split tables" design:

- `AlertGroup`: one grouped webhook event
- `GroupLabel`, `CommonLabel`, `CommonAnnotation`: group-level labels/annotations
- `Alert`: alert-level event rows within a group
- `AlertLabel`, `AlertAnnotation`: alert-level labels/annotations
- `Model`: schema version

## Read-Only Export User (MySQL)

Use a dedicated read-only account:

```sql
CREATE USER 'exporter'@'%' IDENTIFIED BY '123456';
GRANT SELECT, SHOW VIEW ON alertsnitch.* TO 'exporter'@'%';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'exporter'@'%';
```

## Export Script

Use the repository script (link only):

> [scripts/export/export_alertsnitch_tsv.sh](../../scripts/export/export_alertsnitch_tsv.sh)

What it exports:

- All base tables in `tsv/*.tsv`
- `tsv/closed_loop_alerts.tsv` aggregated by `fingerprint + startsAt`

Optional behavior:

- Set `ONLY_CLOSED=true` to keep only strict closed-loop episodes (`MAX(endsAt) IS NOT NULL`)

## `closed_loop_alerts.tsv` Fields

- `fingerprint`: stable alert fingerprint
- `episode_startsAt`: lifecycle start time (`fingerprint + startsAt`)
- `episode_endsAt`: lifecycle end time (max `endsAt`)
- `start_status` / `end_status`: first/last status in the lifecycle
- `first_received_at` / `last_received_at`: first/last webhook receive time
- `groupKey`: earliest group key for the lifecycle
- `receivers`: deduplicated receiver list
- `alert_labels` / `alert_annotations`: alert-level key/value rollups
- `group_labels` / `common_labels` / `common_annotations`: group-level key/value rollups

## Optional: Convert TSV to CSV

```python
import pandas as pd

inp = "closed_loop_alerts.tsv"
out = "closed_loop_alerts.csv"

df = pd.read_csv(inp, sep="\t", dtype=str, keep_default_na=False)
df.to_csv(out, index=False, encoding="utf-8-sig")
print("Done:", out)
```
