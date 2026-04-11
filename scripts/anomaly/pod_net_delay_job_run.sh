#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="${HELPER_DIR}/pod_net_delay_helper.sh"
[[ -f "$HELPER" ]] || { echo "ERROR: helper not found: $HELPER"; exit 1; }

CHAOS_NS="${CHAOS_NS:-chaosblade}"

# == Environment Variables ================================================================================

TARGET_NS="gitea"  # database, zot, wiki, gitea, rt
POD_LABELS="app.kubernetes.io/instance=gitea"
# DATABASE
# mysql： statefulset.kubernetes.io/pod-name=mysql8-primary-0
# redis： statefulset.kubernetes.io/pod-name=redis-ha-node-0
# pg：statefulset.kubernetes.io/pod-name=pg-postgresql-primary-0
## zot: app.kubernetes.io/instance=zot
## wiki: app.kubernetes.io/instance=wiki
## gitea： app.kubernetes.io/instance=gitea
## rt： app.kubernetes.io/instance=rt

CLEANUP="true"

# delay keys
DELAY_TIME_MS="100"      # required
DELAY_OFFSET_MS="50"
INTERFACE="eth0"

# optional selector extras (use "-" to disable)
EVICT_COUNT="-"
EVICT_PERCENT="-"
WAITING_TIME="-"

# optional filters
DELAY_LOCAL_PORT="-"
DELAY_REMOTE_PORT="-"
DELAY_DESTINATION_IP="-"
DELAY_EXCLUDE_PORT="-"
DELAY_EXCLUDE_IP="-"

# optional flags
DELAY_FORCE="false"
DELAY_IGNORE_PEER_PORT="false"

# runtime control
DELAY_MIN_HOLD_SECONDS="600"
DELAY_MAX_HOLD_SECONDS="1200"
DELAY_TIMEOUT_PADDING="30"
# DELAY_HOLD_SECONDS="900"

LOG_DIR="/logs"

# Notes:
# 1) Do not parse POD_NAME here; let the helper handle SELECTOR/SELECTOR_MODE (it will write POD_NAME into the env CM)
# 2) The helper will write POD_LABELS as "-", so run.sh clearly uses the names mode (more deterministic)

args=(
  "TARGET_NS=$TARGET_NS"
  "SELECTOR=$POD_LABELS"
  "SELECTOR_MODE=first"     # newest|first|random

  "CLEANUP=$CLEANUP"

  "DELAY_TIME_MS=$DELAY_TIME_MS"
  "DELAY_OFFSET_MS=$DELAY_OFFSET_MS"
  "INTERFACE=$INTERFACE"

  "EVICT_COUNT=$EVICT_COUNT"
  "EVICT_PERCENT=$EVICT_PERCENT"
  "WAITING_TIME=$WAITING_TIME"

  "DELAY_LOCAL_PORT=$DELAY_LOCAL_PORT"
  "DELAY_REMOTE_PORT=$DELAY_REMOTE_PORT"
  "DELAY_DESTINATION_IP=$DELAY_DESTINATION_IP"
  "DELAY_EXCLUDE_PORT=$DELAY_EXCLUDE_PORT"
  "DELAY_EXCLUDE_IP=$DELAY_EXCLUDE_IP"

  "DELAY_FORCE=$DELAY_FORCE"
  "DELAY_IGNORE_PEER_PORT=$DELAY_IGNORE_PEER_PORT"

  "DELAY_MIN_HOLD_SECONDS=$DELAY_MIN_HOLD_SECONDS"
  "DELAY_MAX_HOLD_SECONDS=$DELAY_MAX_HOLD_SECONDS"
  "DELAY_TIMEOUT_PADDING=$DELAY_TIMEOUT_PADDING"
  # "DELAY_HOLD_SECONDS=$DELAY_HOLD_SECONDS"

  "LOG_DIR=$LOG_DIR"
)

echo "Apply helper in chaos ns: $CHAOS_NS"
echo "Target workload ns: $TARGET_NS, selector: $POD_LABELS"

NS="$CHAOS_NS" bash "$HELPER" install
NS="$CHAOS_NS" bash "$HELPER" set "${args[@]}"
NS="$CHAOS_NS" bash "$HELPER" install job
NS="$CHAOS_NS" bash "$HELPER" job run
# NS="$CHAOS_NS" bash "$HELPER" job logs last
