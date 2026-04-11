#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_disk_io_error_fixed_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"
CONTAINER_NAME="busybox"

# choose ONE: POD_NAME or POD_LABELS
POD_NAME=""          # optional: fixed pod name; empty => resolve by labels

# optional eviction pre-step (use '-' to disable)
EVICT_COUNT="-"      # e.g. "1"
EVICT_PERCENT="-"    # e.g. "50"
WAITING_TIME="-"     # e.g. "20s" "1m"

BLADE_NAME="chaosblade-pod-io-error-fixed-payload"
CLEANUP="true"

# IO error params (fixed)
IO_METHOD="read"         # read / write / open / fsync / rename ...
IO_ERRNO="5"             # e.g. 5 (EIO)
IO_PERCENT="100"         # hit percent
IO_PATH="/data/conf"     # must be inside injected directory

# runtime control
IO_HOLD_SECONDS="120"    # fixed hold seconds (recommended for "fixed")
IO_TIMEOUT_PADDING="30"

# optional (if your script supports random hold too)
# IO_MIN_HOLD_SECONDS="120"
# IO_MAX_HOLD_SECONDS="300"

# host mounts / logging
CGROUP_ROOT="/host-sys/fs/cgroup"
LOG_DIR="/logs"

# cron controls
CRON_SCHEDULE="0 * * * *"
CRON_SUSPEND="false"

# --- resolve POD_NAME dynamically (newest Running pod by label) ---
if [[ -z "${POD_NAME:-}" ]]; then
  POD_NAME="$(
    kubectl -n "$TARGET_NS" get pod -l "$POD_LABELS" \
      --field-selector=status.phase=Running \
      --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | tail -n 1
  )"
fi
[[ -n "$POD_NAME" ]] || { echo "ERROR: cannot resolve POD_NAME by labels: ns=$TARGET_NS labels=$POD_LABELS"; exit 1; }

args=(
  "TARGET_NS=$TARGET_NS"
  "POD_NAME=$POD_NAME"
  "POD_LABELS=$POD_LABELS"
  "CONTAINER_NAME=$CONTAINER_NAME"

  "EVICT_COUNT=$EVICT_COUNT"
  "EVICT_PERCENT=$EVICT_PERCENT"
  "WAITING_TIME=$WAITING_TIME"

  "BLADE_NAME=$BLADE_NAME"
  "CLEANUP=$CLEANUP"

  "IO_METHOD=$IO_METHOD"
  "IO_ERRNO=$IO_ERRNO"
  "IO_PERCENT=$IO_PERCENT"
  "IO_PATH=$IO_PATH"

  "IO_HOLD_SECONDS=$IO_HOLD_SECONDS"
  "IO_TIMEOUT_PADDING=$IO_TIMEOUT_PADDING"

  # optional random hold (if supported)
  # "IO_MIN_HOLD_SECONDS=$IO_MIN_HOLD_SECONDS"
  # "IO_MAX_HOLD_SECONDS=$IO_MAX_HOLD_SECONDS"

  "CGROUP_ROOT=$CGROUP_ROOT"
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
  "activeDeadlineSeconds=3600" \
  "ttlSecondsAfterFinished=300"

bash $HELPER cron resume
bash $HELPER cron status
