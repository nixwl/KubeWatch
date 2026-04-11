#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_disk_io_delay_intermit_helper.sh"

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

BLADE_NAME="chaosblade-pod-io-delay-intermit-payload"
CLEANUP="true"

# IO delay params
IO_METHOD="read"         # read / write / open / fsync / rename ...
IO_DELAY_MS="1000"       # hit => delay 1000ms
IO_PERCENT="100"         # hit percent for "slow" phase
IO_PATH="/data/conf"     # must be inside injected directory

# ====== intermit core params ======
IO_MIN_SLOW_SECONDS="30"
IO_MAX_SLOW_SECONDS="120"
IO_MIN_GAP_SECONDS="60"
IO_MAX_GAP_SECONDS="300"
IO_MIN_CYCLES="3"
IO_MAX_CYCLES="6"
IO_TIMEOUT_PADDING="30"

# optional fixed overrides (bypass random ranges)
# IO_SLOW_SECONDS="60"
# IO_GAP_SECONDS="120"
# IO_CYCLES="4"

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
  "IO_DELAY_MS=$IO_DELAY_MS"
  "IO_PERCENT=$IO_PERCENT"
  "IO_PATH=$IO_PATH"

  "IO_MIN_SLOW_SECONDS=$IO_MIN_SLOW_SECONDS"
  "IO_MAX_SLOW_SECONDS=$IO_MAX_SLOW_SECONDS"
  "IO_MIN_GAP_SECONDS=$IO_MIN_GAP_SECONDS"
  "IO_MAX_GAP_SECONDS=$IO_MAX_GAP_SECONDS"
  "IO_MIN_CYCLES=$IO_MIN_CYCLES"
  "IO_MAX_CYCLES=$IO_MAX_CYCLES"
  "IO_TIMEOUT_PADDING=$IO_TIMEOUT_PADDING"

  # optional fixed overrides (choose any)
  # "IO_SLOW_SECONDS=$IO_SLOW_SECONDS"
  # "IO_GAP_SECONDS=$IO_GAP_SECONDS"
  # "IO_CYCLES=$IO_CYCLES"

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
