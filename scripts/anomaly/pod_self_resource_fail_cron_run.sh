#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_self_resource_fail_helper.sh"

# == Environment Variables ================================================================================

# target pod selector
TARGET_NS="default"

# choose ONE (preferred): resolve by label -> newest Running pod
POD_LABELS="app=stress-test"
# OR: fixed pod name
POD_NAME=""

# optional eviction knobs (choose ONE: EVICT_COUNT or EVICT_PERCENT)
EVICT_COUNT=""
EVICT_PERCENT=""
WAITING_TIME="20s"

# fail controls
CLEANUP="true"

FAIL_ENABLE_TIMEOUT="true"

FAIL_MIN_HOLD_SECONDS="600"
FAIL_MAX_HOLD_SECONDS="1200"
FAIL_TIMEOUT_PADDING="30"
# FAIL_HOLD_SECONDS="900"          # optional fixed hold (bypass random [min,max])

# logs
LOG_DIR="/logs"

# cron controls
CRON_SCHEDULE="0 * * * *"
CRON_SUSPEND="false"

# --- resolve POD_NAME dynamically (newest Running pod by label) ---
if [[ -z "${POD_NAME}" ]]; then
  POD_NAME="$(
    kubectl -n "$TARGET_NS" get pod -l "$POD_LABELS" \
      --field-selector=status.phase=Running \
      --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | tail -n 1
  )"
fi
[[ -n "$POD_NAME" ]] || { echo "ERROR: cannot resolve POD_NAME (ns=$TARGET_NS labels=$POD_LABELS)"; exit 1; }

args=(
  "TARGET_NS=$TARGET_NS"
  "POD_NAME=$POD_NAME"
  "POD_LABELS=$POD_LABELS"

  "EVICT_COUNT=$EVICT_COUNT"
  "EVICT_PERCENT=$EVICT_PERCENT"
  "WAITING_TIME=$WAITING_TIME"

  "CLEANUP=$CLEANUP"

  "FAIL_ENABLE_TIMEOUT=$FAIL_ENABLE_TIMEOUT"
  "FAIL_MIN_HOLD_SECONDS=$FAIL_MIN_HOLD_SECONDS"
  "FAIL_MAX_HOLD_SECONDS=$FAIL_MAX_HOLD_SECONDS"
  "FAIL_TIMEOUT_PADDING=$FAIL_TIMEOUT_PADDING"
  # "FAIL_HOLD_SECONDS=$FAIL_HOLD_SECONDS"

  "LOG_DIR=$LOG_DIR"
)

bash "$HELPER" install
bash "$HELPER" set "${args[@]}"

bash "$HELPER" install cron
bash "$HELPER" cron set \
  "schedule=$CRON_SCHEDULE" \
  "suspend=$CRON_SUSPEND" \
  "concurrencyPolicy=Forbid" \
  "startingDeadlineSeconds=60" \
  "successfulJobsHistoryLimit=1" \
  "failedJobsHistoryLimit=1" \
  "backoffLimit=0" \
  "activeDeadlineSeconds=7200" \
  "ttlSecondsAfterFinished=300"

bash "$HELPER" cron resume
bash "$HELPER" cron status
