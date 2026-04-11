#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_mem_spike_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"
CONTAINER_NAME="busybox"

CLEANUP="true"

SPIKE_PERCENT="85"
SPIKE_RAMP_SECONDS="2"
SPIKE_MIN_HOLD_SECONDS="30"
SPIKE_MAX_HOLD_SECONDS="90"
SPIKE_TIMEOUT_PADDING="30"
# SPIKE_HOLD_SECONDS="60"

MAX_MEM_PERCENT="90"

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

  "SPIKE_PERCENT=$SPIKE_PERCENT"
  "SPIKE_RAMP_SECONDS=$SPIKE_RAMP_SECONDS"
  "SPIKE_MIN_HOLD_SECONDS=$SPIKE_MIN_HOLD_SECONDS"
  "SPIKE_MAX_HOLD_SECONDS=$SPIKE_MAX_HOLD_SECONDS"
  "SPIKE_TIMEOUT_PADDING=$SPIKE_TIMEOUT_PADDING"
  # "SPIKE_HOLD_SECONDS=$SPIKE_HOLD_SECONDS"

  "MAX_MEM_PERCENT=$MAX_MEM_PERCENT"

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
  "activeDeadlineSeconds=3600" \
  "ttlSecondsAfterFinished=300"

bash $HELPER cron resume
bash $HELPER cron status
