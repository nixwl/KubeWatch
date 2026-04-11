#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_net_loss_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"
CONTAINER_NAME="busybox"

# optional selector extras (use '-' to disable)
POD_NAME=""               # optional: fixed pod name; empty => resolve by labels
EVICT_COUNT="-"           # e.g. "1"
EVICT_PERCENT="-"         # e.g. "50"
WAITING_TIME="-"          # e.g. "20s" "1m"

BLADE_NAME="chaosblade-pod-net-loss-payload"
CLEANUP="true"

# loss params
LOSS_PERCENT="30"         # 0-100
INTERFACE="eth0"          # IMPORTANT: pod netns interface usually "eth0"

# optional filters
LOSS_LOCAL_PORT="-"
LOSS_REMOTE_PORT="-"
LOSS_DESTINATION_IP="-"
LOSS_EXCLUDE_IP="-"
LOSS_EXCLUDE_PORT="-"

# optional flags
LOSS_FORCE="false"
LOSS_IGNORE_PEER_PORT="false"

# runtime control
LOSS_MIN_HOLD_SECONDS="600"
LOSS_MAX_HOLD_SECONDS="1200"
LOSS_TIMEOUT_PADDING="30"
# LOSS_HOLD_SECONDS="900"

LOG_DIR="/logs"

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

  "LOSS_PERCENT=$LOSS_PERCENT"
  "INTERFACE=$INTERFACE"

  "LOSS_LOCAL_PORT=$LOSS_LOCAL_PORT"
  "LOSS_REMOTE_PORT=$LOSS_REMOTE_PORT"
  "LOSS_DESTINATION_IP=$LOSS_DESTINATION_IP"
  "LOSS_EXCLUDE_IP=$LOSS_EXCLUDE_IP"
  "LOSS_EXCLUDE_PORT=$LOSS_EXCLUDE_PORT"

  "LOSS_FORCE=$LOSS_FORCE"
  "LOSS_IGNORE_PEER_PORT=$LOSS_IGNORE_PEER_PORT"

  "LOSS_MIN_HOLD_SECONDS=$LOSS_MIN_HOLD_SECONDS"
  "LOSS_MAX_HOLD_SECONDS=$LOSS_MAX_HOLD_SECONDS"
  "LOSS_TIMEOUT_PADDING=$LOSS_TIMEOUT_PADDING"
  # "LOSS_HOLD_SECONDS=$LOSS_HOLD_SECONDS"

  "LOG_DIR=$LOG_DIR"
)

bash $HELPER install
bash "$HELPER" set "${args[@]}"
bash $HELPER install job
bash $HELPER job run
