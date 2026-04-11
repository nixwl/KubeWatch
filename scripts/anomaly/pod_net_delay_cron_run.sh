#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_net_delay_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"
CONTAINER_NAME="busybox"

# optional selector extras (use '-' to disable)
POD_NAME=""               # optional: fixed pod name; empty => resolve by labels
EVICT_COUNT="-"           # e.g. "1"
EVICT_PERCENT="-"         # e.g. "50"
WAITING_TIME="-"          # e.g. "20s" "1m"

BLADE_NAME="chaosblade-pod-net-delay-payload"
CLEANUP="true"

# delay params (ms)
DELAY_TIME_MS="150"
DELAY_OFFSET_MS="50"
INTERFACE="eth0"          # IMPORTANT: pod netns interface usually "eth0"

# optional filters
DELAY_LOCAL_PORT="-"
DELAY_REMOTE_PORT="-"
DELAY_DESTINATION_IP="-"
DELAY_EXCLUDE_IP="-"
DELAY_EXCLUDE_PORT="-"

# optional flags
DELAY_FORCE="false"
DELAY_IGNORE_PEER_PORT="false"

# runtime control
DELAY_MIN_HOLD_SECONDS="600"
DELAY_MAX_HOLD_SECONDS="1200"
DELAY_TIMEOUT_PADDING="30"
# DELAY_HOLD_SECONDS="900"

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

  "DELAY_TIME_MS=$DELAY_TIME_MS"
  "DELAY_OFFSET_MS=$DELAY_OFFSET_MS"
  "INTERFACE=$INTERFACE"

  "DELAY_LOCAL_PORT=$DELAY_LOCAL_PORT"
  "DELAY_REMOTE_PORT=$DELAY_REMOTE_PORT"
  "DELAY_DESTINATION_IP=$DELAY_DESTINATION_IP"
  "DELAY_EXCLUDE_IP=$DELAY_EXCLUDE_IP"
  "DELAY_EXCLUDE_PORT=$DELAY_EXCLUDE_PORT"

  "DELAY_FORCE=$DELAY_FORCE"
  "DELAY_IGNORE_PEER_PORT=$DELAY_IGNORE_PEER_PORT"

  "DELAY_MIN_HOLD_SECONDS=$DELAY_MIN_HOLD_SECONDS"
  "DELAY_MAX_HOLD_SECONDS=$DELAY_MAX_HOLD_SECONDS"
  "DELAY_TIMEOUT_PADDING=$DELAY_TIMEOUT_PADDING"
  # "DELAY_HOLD_SECONDS=$DELAY_HOLD_SECONDS"

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
