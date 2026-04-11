#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_self_resource_delete_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"

# --- choose ONE: POD_NAME or POD_LABELS ---
# POD_NAME="stress-test-xxxx"   # optional: set fixed target pod
# POD_LABELS="app=stress-test"  # default: resolve by label

CLEANUP="true"

# evict strategy: choose ONE (leave the other empty/"-")
EVICT_COUNT="1"
EVICT_PERCENT=""

WAITING_TIME="20s"   # default 20s

# runtime controls
DELETE_MIN_HOLD_SECONDS="60"
DELETE_MAX_HOLD_SECONDS="120"
DELETE_TIMEOUT_PADDING="15"
# DELETE_HOLD_SECONDS="90"      # optional fixed hold

# optional flags
DELETE_ENABLE_TIMEOUT="false"
LOG_DIR="/logs"

# cron controls
CRON_SCHEDULE="0 * * * *"
CRON_SUSPEND="false"

# --- resolve POD_NAME dynamically (newest Running pod by label) ---
POD_NAME="${POD_NAME:-}"
if [[ -z "$POD_NAME" || "$POD_NAME" == "-" ]]; then
  POD_NAME="$(
    kubectl -n "$TARGET_NS" get pod -l "$POD_LABELS" \
      --field-selector=status.phase=Running \
      --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | tail -n 1
  )"
fi
[[ -n "$POD_NAME" ]] || { echo "ERROR: cannot resolve POD_NAME (ns=$TARGET_NS labels=$POD_LABELS)"; exit 1; }

# normalize mutually exclusive eviction knobs
if [[ -n "${EVICT_COUNT:-}" && -n "${EVICT_PERCENT:-}" ]]; then
  echo "ERROR: EVICT_COUNT and EVICT_PERCENT are mutually exclusive. Choose ONE."
  exit 1
fi
EVICT_COUNT="${EVICT_COUNT:-}"
EVICT_PERCENT="${EVICT_PERCENT:-}"

args=(
  "TARGET_NS=$TARGET_NS"
  "POD_NAME=$POD_NAME"
  "POD_LABELS=$POD_LABELS"

  "CLEANUP=$CLEANUP"

  "EVICT_COUNT=$EVICT_COUNT"
  "EVICT_PERCENT=$EVICT_PERCENT"
  "WAITING_TIME=$WAITING_TIME"

  "DELETE_MIN_HOLD_SECONDS=$DELETE_MIN_HOLD_SECONDS"
  "DELETE_MAX_HOLD_SECONDS=$DELETE_MAX_HOLD_SECONDS"
  "DELETE_TIMEOUT_PADDING=$DELETE_TIMEOUT_PADDING"
  # "DELETE_HOLD_SECONDS=$DELETE_HOLD_SECONDS"

  "DELETE_ENABLE_TIMEOUT=$DELETE_ENABLE_TIMEOUT"
  "LOG_DIR=$LOG_DIR"
)

bash $HELPER install
bash "$HELPER" set "${args[@]}"

bash $HELPER install cron
bash "$HELPER" cron set \
  "schedule=$CRON_SCHEDULE" \
  "suspend=$CRON_SUSPEND" \
  "concurrencyPolicy=Forbid" \
  "startingDeadlineSeconds=60" \
  "successfulJobsHistoryLimit=1" \
  "failedJobsHistoryLimit=1" \
  "backoffLimit=0" \
  "activeDeadlineSeconds=600" \
  "ttlSecondsAfterFinished=300"

bash $HELPER cron resume
bash $HELPER cron status
