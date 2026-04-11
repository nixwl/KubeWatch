#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_cpu_spike_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"
CONTAINER_NAME="busybox"

SPIKE_PERCENT="90"
SPIKE_RAMP_SECONDS="5"
SPIKE_MIN_HOLD_SECONDS="200"
SPIKE_MAX_HOLD_SECONDS="300"
SPIKE_TIMEOUT_PADDING="30"
CLEANUP="true"

# optional cpu pinning (choose ONE)
CPU_COUNT=""
CPU_LIST=""

# cron settings
CRON_SCHEDULE="*/20 * * * *"
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

  "SPIKE_PERCENT=$SPIKE_PERCENT"
  "SPIKE_RAMP_SECONDS=$SPIKE_RAMP_SECONDS"
  "SPIKE_MIN_HOLD_SECONDS=$SPIKE_MIN_HOLD_SECONDS"
  "SPIKE_MAX_HOLD_SECONDS=$SPIKE_MAX_HOLD_SECONDS"
  "SPIKE_TIMEOUT_PADDING=$SPIKE_TIMEOUT_PADDING"
  "CLEANUP=$CLEANUP"

  # optional cpu pinning (choose ONE)
  "CPU_COUNT=$CPU_COUNT"
  "CPU_LIST=$CPU_LIST"
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
  "activeDeadlineSeconds=900" \
  "ttlSecondsAfterFinished=300" \
  "backoffLimit=0"

bash $HELPER cron resume
bash $HELPER cron status