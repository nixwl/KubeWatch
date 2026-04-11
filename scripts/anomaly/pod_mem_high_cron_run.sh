#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_mem_high_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"
CONTAINER_NAME="busybox"

CLEANUP="true"

# choose ONE: PERCENT or RESERVE_MB
PERCENT="85"
RESERVE_MB=""

MAX_MEM_PERCENT="90"

RAMP_SECONDS="180"
MIN_HOLD_SECONDS="6000"
MAX_HOLD_SECONDS="12000"
TIMEOUT_PADDING="30"
# HOLD_SECONDS="7200"

MEM_MODE="ram"         # ram / cache
MEM_RATE=""            # MB/s (optional)

CGROUP_ROOT="/host-sys/fs/cgroup"
LOG_DIR="/logs"

# cron controls
CRON_SCHEDULE="0 * * * *"
CRON_SUSPEND="false"

# --- resolve POD_NAME dynamically (newest Running pod by label) ---
POD_NAME="$(
  kubectl -n "$TARGET_NS" get pod -l "$POD_LABELS" \
    --field-selector=status.phase=Running \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | tail -n 1
)"
[[ -n "$POD_NAME" ]] || { echo "ERROR: cannot resolve POD_NAME by labels: ns=$TARGET_NS labels=$POD_LABELS"; exit 1; }

args=(
  "TARGET_NS=$TARGET_NS"
  "POD_NAME=$POD_NAME"
  "CONTAINER_NAME=$CONTAINER_NAME"

  "CLEANUP=$CLEANUP"

  # choose ONE: PERCENT or RESERVE_MB
  "PERCENT=$PERCENT"
  "RESERVE_MB=$RESERVE_MB"
  "MAX_MEM_PERCENT=$MAX_MEM_PERCENT"

  "RAMP_SECONDS=$RAMP_SECONDS"
  "MIN_HOLD_SECONDS=$MIN_HOLD_SECONDS"
  "MAX_HOLD_SECONDS=$MAX_HOLD_SECONDS"
  "TIMEOUT_PADDING=$TIMEOUT_PADDING"
  # "HOLD_SECONDS=$HOLD_SECONDS"

  "MEM_MODE=$MEM_MODE"
  "MEM_RATE=$MEM_RATE"

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
  "activeDeadlineSeconds=20000" \
  "ttlSecondsAfterFinished=300"

bash $HELPER cron resume
bash $HELPER cron status
