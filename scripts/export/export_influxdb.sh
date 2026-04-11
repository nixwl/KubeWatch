#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================================================
#  InfluxDB v2 CSV full dump (hourly windows) - TWO-STAGE (raw -> gzip) to avoid truncated gzip artifacts
#
#  Why two-stage?
#    A) Write raw query output to .raw.tmp first (plain text). If query is interrupted, you see it here.
#    B) Gzip the completed raw file into .csv.gz.tmp, then `gzip -t` verify, then mv to final.
#
#  This eliminates “half gzip” caused by upstream disconnect or mid-stream kill while writing gzip footer.
#
#  Behavior:
#    - Skip if outfile exists
#    - Retry + adaptive split on failure (3600s -> 600 -> 120 -> 60)
#    - Record failing hour windows to FAILDIR for later retry
# ==========================================================================================================

# ====== Config ======
ORG="${ORG:-data-center}"
BUCKET="${BUCKET:-producer}"
OUTDIR="${OUTDIR:-/root/influxDB/v2/export}"
LOGDIR="${LOGDIR:-/root/influxDB/v2/export-logs}"
FAILDIR="${FAILDIR:-/root/influxDB/v2/export-fails}"   # failed window record dir

LOCKDIR="/tmp/cron_csv_full_dump.${BUCKET}.lock"

# ====== Force GLOBAL UTC ======
export TZ=UTC
export LC_ALL=C
export LANG=C

mkdir -p "$OUTDIR" "$LOGDIR" "$FAILDIR"

LOGFILE="$LOGDIR/export_${BUCKET}_$(date -u +%Y%m%d).log"
log() { echo "$(date -u -Is) $*" | tee -a "$LOGFILE" || true; }

# ====== Lock ======
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  log "[WARN] Another export is running (lock=$LOCKDIR). Exit."
  exit 0
fi

# tmp paths for trap cleanup
tmp_raw=""
tmp_gz=""

cleanup() {
  rm -f "${tmp_raw:-}" "${tmp_gz:-}" >/dev/null 2>&1 || true
  rm -rf "$LOCKDIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ====== Knobs (UTC) ======
START_TAG="${START_TAG:-20260125_0700Z}"            # YYYYMMDD_HH00Z
END_UTC="${END_UTC:-}"                              # optional, RFC3339 Z, exclusive boundary

SLEEP_SECONDS="${SLEEP_SECONDS:-10}"
GZIP_LEVEL="${GZIP_LEVEL:-3}"
RETRY_MAX="${RETRY_MAX:-2}"

# only retry fails, do not advance new hours
ONLY_RETRY_FAILS="${ONLY_RETRY_FAILS:-false}"       # true/false

# adaptive slice levels: start from 3600s (one-hour window), split on failure
SLICE_LEVELS_SEC=(${SLICE_LEVELS_SEC:-3600 1800 900})

BUCKET_TAG="${BUCKET//[^A-Za-z0-9._-]/_}"

# ====== Helpers ======
fmt_rfc3339() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
fmt_tag_hour() { date -u -d "@$1" +%Y%m%d_%H00Z; }
fmt_tag_min()  { date -u -d "@$1" +%Y%m%d_%H%MZ; }

fail_key() {
  local s="$1" e="$2"
  echo "$(fmt_tag_hour "$s")__$(fmt_tag_hour "$e")"
}

record_fail() {
  local s="$1" e="$2"
  local key; key="$(fail_key "$s" "$e")"
  local f="$FAILDIR/${BUCKET_TAG}_${key}.fail"
  cat > "$f" <<EOF
bucket=$BUCKET
org=$ORG
start_epoch=$s
stop_epoch=$e
start_utc=$(fmt_rfc3339 "$s")
stop_utc=$(fmt_rfc3339 "$e")
recorded_at=$(date -u -Is)
EOF
  log "[WARN] Recorded FAIL window: $(fmt_rfc3339 "$s")..$(fmt_rfc3339 "$e") -> $f"
}

clear_fail() {
  local s="$1" e="$2"
  local key; key="$(fail_key "$s" "$e")"
  rm -f "$FAILDIR/${BUCKET_TAG}_${key}.fail" >/dev/null 2>&1 || true
}

list_fails_sorted() {
  ls -1 "$FAILDIR/${BUCKET_TAG}_"*.fail 2>/dev/null | sort || true
}

# ====== Parse START_TAG -> start_epoch (UTC aligned hour) ======
if [[ ! "$START_TAG" =~ ^[0-9]{8}_[0-9]{4}Z$ ]]; then
  log "[ERROR] START_TAG invalid: $START_TAG (expect YYYYMMDD_HH00Z like 20260125_0700Z)"
  exit 1
fi

ymd="${START_TAG:0:8}"
hm="${START_TAG:9:4}"
START_UTC="${ymd:0:4}-${ymd:4:2}-${ymd:6:2}T${hm:0:2}:${hm:2:2}:00Z"

start_epoch_raw="$(date -u -d "$START_UTC" +%s)"
start_epoch="$(( (start_epoch_raw / 3600) * 3600 ))"

# ====== Resolve stop_epoch (UTC aligned hour, exclusive) ======
if [[ -n "$END_UTC" ]]; then
  end_epoch_raw="$(date -u -d "$END_UTC" +%s)"
  stop_epoch="$(( (end_epoch_raw / 3600) * 3600 ))"
else
  now_epoch="$(date -u +%s)"
  stop_epoch="$(( (now_epoch / 3600) * 3600 ))"
fi

if (( stop_epoch <= start_epoch )); then
  log "[ERROR] stop_epoch <= start_epoch (start=$(fmt_rfc3339 "$start_epoch"), stop=$(fmt_rfc3339 "$stop_epoch"))"
  exit 1
fi

log "[INFO] UTC start=$(fmt_rfc3339 "$start_epoch")"
log "[INFO] UTC stop(exclusive)=$(fmt_rfc3339 "$stop_epoch")"
log "[INFO] bucket=$BUCKET outdir=$OUTDIR faildir=$FAILDIR gzip=$GZIP_LEVEL sleep=${SLEEP_SECONDS}s retry=${RETRY_MAX}"
log "[INFO] slice_levels_sec=${SLICE_LEVELS_SEC[*]} (start from 3600s)"

# ----------------------------------------------------------------------------------------------------------
# TWO-STAGE EXPORT (raw -> gzip)
#   Stage A: influx query -> raw tmp file (plain text)
#   Stage B: gzip raw tmp -> gzip tmp + gzip -t verify -> mv to final
# ----------------------------------------------------------------------------------------------------------
export_slice() {
  local win_start_epoch="$1"
  local win_stop_epoch="$2"
  local step_sec="$3"

  local win_start_utc; win_start_utc="$(fmt_rfc3339 "$win_start_epoch")"
  local win_stop_utc;  win_stop_utc="$(fmt_rfc3339 "$win_stop_epoch")"

  local start_tag; start_tag="$(fmt_tag_min "$win_start_epoch")"
  local stop_tag;  stop_tag="$(fmt_tag_min "$win_stop_epoch")"

  local step_tag="${step_sec}s"
  local outfile="$OUTDIR/${BUCKET_TAG}_${start_tag}_${stop_tag}_${step_tag}.csv.gz"

  # tmp files (tracked by trap)
  tmp_raw="${outfile}.raw.tmp"
  tmp_gz="${outfile}.tmp"

  # per-slice stderr logs
  local err_influx="$LOGDIR/${BUCKET_TAG}_${start_tag}_${stop_tag}_${step_tag}.influx.stderr.log"
  local err_gzip="$LOGDIR/${BUCKET_TAG}_${start_tag}_${stop_tag}_${step_tag}.gzip.stderr.log"

  if [[ -s "$outfile" ]]; then
    log "[INFO] Skip exists: $outfile"
    return 0
  fi

  log "[INFO] Export slice=${win_start_utc}..${win_stop_utc} step=${step_sec}s -> $outfile"

  local flux
  flux="
from(bucket: \"$BUCKET\")
  |> range(start: time(v: \"$win_start_utc\"), stop: time(v: \"$win_stop_utc\"))
"

  local attempt=1
  while true; do
    rm -f "$tmp_raw" "$tmp_gz" "$err_influx" "$err_gzip" >/dev/null 2>&1 || true

    # ---- Stage A: query -> raw tmp ----------------------------------------------------
    set +e
    stdbuf -oL -eL influx query --org "$ORG" --raw "$flux" > "$tmp_raw" 2> "$err_influx"
    rc_influx=$?
    set -e

    if (( rc_influx != 0 )) || [[ ! -s "$tmp_raw" ]]; then
      raw_size="$(ls -lh "$tmp_raw" 2>/dev/null | awk '{print $5}' || echo NA)"
      err_lines="$(wc -l < "$err_influx" 2>/dev/null || echo 0)"
      log "[WARN] StageA(influx->raw) failed (rc_influx=$rc_influx raw_size=$raw_size err_lines=$err_lines attempt=$attempt/$RETRY_MAX) err_influx=$err_influx"

      if (( attempt >= RETRY_MAX )); then
        rm -f "$tmp_raw" >/dev/null 2>&1 || true
        return 1
      fi
      sleep $((attempt * 3))
      attempt=$((attempt + 1))
      continue
    fi

    # ---- Stage B: raw -> gzip tmp + verify --------------------------------------------
    set +e
    gzip -"${GZIP_LEVEL}" -c "$tmp_raw" > "$tmp_gz" 2> "$err_gzip"
    rc_gzip=$?
    set -e

    if (( rc_gzip != 0 )) || ! gzip -t "$tmp_gz" >/dev/null 2>&1; then
      gz_size="$(ls -lh "$tmp_gz" 2>/dev/null | awk '{print $5}' || echo NA)"
      err_lines="$(wc -l < "$err_gzip" 2>/dev/null || echo 0)"
      log "[WARN] StageB(raw->gzip) failed (rc_gzip=$rc_gzip gz_size=$gz_size err_lines=$err_lines attempt=$attempt/$RETRY_MAX) err_gzip=$err_gzip"

      if (( attempt >= RETRY_MAX )); then
        rm -f "$tmp_raw" "$tmp_gz" >/dev/null 2>&1 || true
        return 1
      fi
      sleep $((attempt * 3))
      attempt=$((attempt + 1))
      continue
    fi

    # ---- Promote: mv gzip tmp -> final (atomic) ---------------------------------------
    mv -f "$tmp_gz" "$outfile"
    rm -f "$tmp_raw" "$err_influx" "$err_gzip" >/dev/null 2>&1 || true

    # reset trap-tracked tmp paths (avoid deleting final by mistake)
    tmp_raw=""
    tmp_gz=""

    log "[INFO] Export ok: $outfile size=$(du -h "$outfile" | awk '{print $1}')"
    return 0
  done
}

export_window_adaptive() {
  local win_start_epoch="$1"
  local win_stop_epoch="$2"
  local level_idx="$3"

  local step_sec="${SLICE_LEVELS_SEC[$level_idx]}"

  if export_slice "$win_start_epoch" "$win_stop_epoch" "$step_sec"; then
    return 0
  fi

  if (( level_idx + 1 >= ${#SLICE_LEVELS_SEC[@]} )); then
    log "[ERROR] Reached smallest slice but still failing: $(fmt_rfc3339 "$win_start_epoch")..$(fmt_rfc3339 "$win_stop_epoch")"
    return 1
  fi

  local next_idx=$((level_idx + 1))
  local next_step="${SLICE_LEVELS_SEC[$next_idx]}"

  log "[WARN] Split window: ${step_sec}s -> ${next_step}s for $(fmt_rfc3339 "$win_start_epoch")..$(fmt_rfc3339 "$win_stop_epoch")"

  local cur="$win_start_epoch"
  while (( cur < win_stop_epoch )); do
    local nxt=$((cur + next_step))
    if (( nxt > win_stop_epoch )); then
      nxt="$win_stop_epoch"
    fi

    export_window_adaptive "$cur" "$nxt" "$next_idx" || return 1

    cur="$nxt"
    if [[ "$SLEEP_SECONDS" != "0" ]]; then
      sleep "$SLEEP_SECONDS"
    fi
  done
}

retry_fail_windows() {
  local files
  files="$(list_fails_sorted)"
  if [[ -z "$files" ]]; then
    log "[INFO] No fail windows to retry."
    return 0
  fi

  log "[INFO] Retrying fail windows..."
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue

    s="$(awk -F'=' '$1=="start_epoch"{print $2}' "$f")"
    e="$(awk -F'=' '$1=="stop_epoch"{print $2}' "$f")"

    if [[ -z "${s:-}" || -z "${e:-}" ]]; then
      log "[WARN] Bad fail file (missing epoch): $f"
      continue
    fi

    log "[INFO] Retry FAIL window: $(fmt_rfc3339 "$s")..$(fmt_rfc3339 "$e") (file=$f)"
    if export_window_adaptive "$s" "$e" 0; then
      clear_fail "$s" "$e"
      log "[INFO] Cleared FAIL window: $(fmt_rfc3339 "$s")..$(fmt_rfc3339 "$e")"
    else
      log "[WARN] Still failing: $(fmt_rfc3339 "$s")..$(fmt_rfc3339 "$e") (keep record)"
    fi
  done <<< "$files"
}

# ====== Phase 1: retry previously failed windows first ======
retry_fail_windows

if [[ "$ONLY_RETRY_FAILS" == "true" ]]; then
  log "[INFO] ONLY_RETRY_FAILS=true, exit after retrying fail windows."
  exit 0
fi

# ====== Phase 2: normal forward hour progression ======
cur="$start_epoch"
while (( cur < stop_epoch )); do
  hour_start="$cur"
  hour_stop="$((cur + 3600))"

  key="$(fail_key "$hour_start" "$hour_stop")"
  if [[ -f "$FAILDIR/${BUCKET_TAG}_${key}.fail" ]]; then
    log "[WARN] Hour window is marked FAIL already, skip for now: $(fmt_rfc3339 "$hour_start")..$(fmt_rfc3339 "$hour_stop")"
    cur="$hour_stop"
    continue
  fi

  if export_window_adaptive "$hour_start" "$hour_stop" 0; then
    clear_fail "$hour_start" "$hour_stop"
  else
    record_fail "$hour_start" "$hour_stop"
  fi

  cur="$hour_stop"
  if [[ "$SLEEP_SECONDS" != "0" ]]; then
    sleep "$SLEEP_SECONDS"
  fi
done

log "[INFO] All done."