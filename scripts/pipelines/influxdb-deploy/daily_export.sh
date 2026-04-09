#!/usr/bin/env bash
set -euo pipefail

# ====== Config ======
ORG="data-center"
BUCKET="monitor.daily"              # bucket name
OUTDIR="/root/influxDB/v2/csv"      # export output directory
LOCKDIR="/tmp/cron_csv.lock"        # export LOCK of directory
LOGDIR="/root/influxDB/v2/log"      # export logs directory

# Enforce UTC globally throughout the script (affecting logs, filenames, and all date calls).
export TZ=UTC

mkdir -p "$OUTDIR" "$LOGDIR"

log() { echo "$(date -u -Is) $*"; }

# ====== Lock (prevent concurrency) ======
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  log "[WARN] Another export is running. Exit."
  exit 0
fi

outfile=""
tmpfile=""

# Clean up locks and temp files on exit to avoid leaving behind incomplete files.
cleanup() {
  rm -f "${tmpfile:-}" >/dev/null 2>&1 || true
  rmdir "$LOCKDIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ====== Time window: previous full hour [start, stop) in UTC ======
now_epoch=$(date -u +%s)
stop_epoch=$(( (now_epoch / 3600) * 3600 ))   # last full hour (UTC)
start_epoch=$(( stop_epoch - 3600 ))          # previous full hour (UTC)

start_utc=$(date -u -d "@$start_epoch" +%Y-%m-%dT%H:%M:%SZ)
stop_utc=$(date -u -d "@$stop_epoch"  +%Y-%m-%dT%H:%M:%SZ)

# file name use UTC hour tag
start_tag=$(date -u -d "@$start_epoch" +%Y%m%d_%H00Z)
stop_tag=$(date -u -d "@$stop_epoch"  +%Y%m%d_%H00Z)

outfile="$OUTDIR/${BUCKET}_${start_tag}_${stop_tag}.csv.gz"
tmpfile="${outfile}.tmp"

log "[INFO] Export bucket=${BUCKET} window=${start_utc}..${stop_utc} -> ${outfile}"

# ====== Skip if exists ======
if [[ -s "$outfile" ]]; then
  log "[INFO] Output exists, skip: $outfile"
  exit 0
fi

# ====== Export ======
# write tmp first, then mv to final file.
influx query --org "$ORG" --raw "
from(bucket: \"$BUCKET\")
  |> range(start: time(v: \"$start_utc\"), stop: time(v: \"$stop_utc\"))
" | gzip -1 > "$tmpfile"

mv -f "$tmpfile" "$outfile"
tmpfile=""  # avoid cleanup of tmpfile since it's already moved to final location.

log "[INFO] Export success: $outfile (size=$(du -h "$outfile" | awk '{print $1}'))"
