#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="${HELPER_DIR}/pod_mem_high_helper.sh"
[[ -f "$HELPER" ]] || { echo "ERROR: helper not found: $HELPER"; exit 1; }

CHAOS_NS="${CHAOS_NS:-chaosblade}"


TARGET_NS="database"
POD_LABELS="statefulset.kubernetes.io/pod-name=redis-ha-node-0"
# DATABASE
# mysql： statefulset.kubernetes.io/pod-name=mysql8-primary-0
# redis： statefulset.kubernetes.io/pod-name=redis-ha-node-0
# pg：statefulset.kubernetes.io/pod-name=pg-postgresql-primary-0
## zot: app.kubernetes.io/instance=zot
## wiki: app.kubernetes.io/instance=wiki
## gitea： app.kubernetes.io/instance=gitea
## rt： app.kubernetes.io/instance=rt
CONTAINER_NAME="redis"
## DATABASE
# mysql： mysql
# redis： "redis sentinel"
# pg:  postgresql
## zot: zot
## wiki: wiki
## gitea:
## rt: main

# mem-high keys (aligned with helper usage / regular scripts)
PERCENT="90"
RAMP_SECONDS="5"
MIN_HOLD_SECONDS="200"
MAX_HOLD_SECONDS="500"
TIMEOUT_PADDING="30"
TIMEOUT="86400"

# ---------- helpers (only sanitize/validate input; do not change your original logic) ----------
clean_val() {
  # Strip \r + leading/trailing whitespace to avoid patching the CM into "looks the same but doesn't match / can't be parsed"
  printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

must_int() {
  local name="$1" val="$2"
  val="$(clean_val "$val")"
  [[ "$val" =~ ^[0-9]+$ ]] || { echo "ERROR: $name must be an integer, got: '$val'"; exit 1; }
}

TARGET_NS="$(clean_val "$TARGET_NS")"
POD_LABELS="$(clean_val "$POD_LABELS")"
CONTAINER_NAME="$(clean_val "$CONTAINER_NAME")"

PERCENT="$(clean_val "$PERCENT")"
RAMP_SECONDS="$(clean_val "$RAMP_SECONDS")"
MIN_HOLD_SECONDS="$(clean_val "$MIN_HOLD_SECONDS")"
MAX_HOLD_SECONDS="$(clean_val "$MAX_HOLD_SECONDS")"
TIMEOUT_PADDING="$(clean_val "$TIMEOUT_PADDING")"
TIMEOUT="$(clean_val "$TIMEOUT")"

must_int "PERCENT" "$PERCENT"
must_int "RAMP_SECONDS" "$RAMP_SECONDS"
must_int "MIN_HOLD_SECONDS" "$MIN_HOLD_SECONDS"
must_int "MAX_HOLD_SECONDS" "$MAX_HOLD_SECONDS"
must_int "TIMEOUT_PADDING" "$TIMEOUT_PADDING"
must_int "TIMEOUT" "$TIMEOUT"

args=(
  "TARGET_NS=$TARGET_NS"
  "SELECTOR=$POD_LABELS"
  "SELECTOR_MODE=first"
  "CONTAINER_NAME=$CONTAINER_NAME"

  "PERCENT=$PERCENT"
  "RAMP_SECONDS=$RAMP_SECONDS"
  "MIN_HOLD_SECONDS=$MIN_HOLD_SECONDS"
  "MAX_HOLD_SECONDS=$MAX_HOLD_SECONDS"
  "TIMEOUT_PADDING=$TIMEOUT_PADDING"

  "TIMEOUT=$TIMEOUT"
)

echo "Apply helper in chaos ns: $CHAOS_NS"
echo "Target workload ns: $TARGET_NS, selector: $POD_LABELS, container: $CONTAINER_NAME"

NS="$CHAOS_NS" bash "$HELPER" install
NS="$CHAOS_NS" bash "$HELPER" set "${args[@]}"
NS="$CHAOS_NS" bash "$HELPER" install job
NS="$CHAOS_NS" bash "$HELPER" job run
# NS="$CHAOS_NS" bash "$HELPER" job logs last