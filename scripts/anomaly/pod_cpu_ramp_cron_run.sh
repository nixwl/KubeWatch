#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_cpu_ramp_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"
CONTAINER_NAME="busybox"

HIGH="85"
LOW="80"
RAMP_SECONDS="10"
HOLD_SECONDS="50"
CYCLES="5"

# Cron schedule (example)
CRON_SCHEDULE="30 */4 * * *"

# Compute TOTAL_SECONDS for CronJob.jobTemplate.spec.activeDeadlineSeconds
EXTRA_BUFFER="60"
TOTAL_SECONDS=$(( CYCLES * (RAMP_SECONDS + HOLD_SECONDS) + EXTRA_BUFFER ))

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
  "HIGH=$HIGH"
  "LOW=$LOW"
  "RAMP_SECONDS=$RAMP_SECONDS"
  "HOLD_SECONDS=$HOLD_SECONDS"
  "CYCLES=$CYCLES"
)

# install ConfigMaps only
bash $HELPER install

# patch env configmap
bash "$HELPER" set "${args[@]}"

# install CronJob only
bash $HELPER install cron

# patch cron fields (supported by helper)
bash "$HELPER" cron set activeDeadlineSeconds="$TOTAL_SECONDS"
bash "$HELPER" cron set schedule="$CRON_SCHEDULE"
bash "$HELPER" cron set concurrencyPolicy=Forbid startingDeadlineSeconds=60 successfulJobsHistoryLimit=1 failedJobsHistoryLimit=1
bash "$HELPER" cron set backoffLimit=0 ttlSecondsAfterFinished=3600

# enable cron
bash "$HELPER" cron enable

# # status
# bash "$HELPER" cron status