#!/usr/bin/env bash
set -euo pipefail

# == Environment Variables ==================================================================================
HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_net_delay_helper.sh"

BLADE_NAME="chaosblade-singlenode-net-delay-payload"
TARGET_NODE="emanage1"

TIME_MS="150"
OFFSET_MS="50"
INTERFACE="ens33"

LOCAL_PORT="-"
REMOTE_PORT="-"
DESTINATION_IP="-"
EXCLUDE_IP="-"
EXCLUDE_PORT="22"

FORCE="false"
IGNORE_PEER_PORT="false"

MIN_HOLD_SECONDS="600"
MAX_HOLD_SECONDS="1200"
# HOLD_SECONDS="900"    # Optional: fixed hold (use this value if set)
TIMEOUT_PADDING="30"

LOG_DIR="/logs"
CLEANUP="true"

# Cron schedule (example: run at minute 30 every 4 hours)
CRON_SCHEDULE="30 */4 * * *"

# CronJob activeDeadlineSeconds uses the "worst-case" value:
# - hold may be MAX_HOLD_SECONDS (or the fixed HOLD_SECONDS value)
# - timeout = hold + TIMEOUT_PADDING
# - add a 60s buffer to cover additional apply/wait/cleanup overhead
if [[ -n "${HOLD_SECONDS:-}" && "${HOLD_SECONDS}" != "-" ]]; then
  TOTAL_SECONDS=$(( HOLD_SECONDS + TIMEOUT_PADDING + 60 ))
else
  TOTAL_SECONDS=$(( MAX_HOLD_SECONDS + TIMEOUT_PADDING + 60 ))
fi

args=(
  "BLADE_NAME=$BLADE_NAME"
  "TARGET_NODE=$TARGET_NODE"

  "TIME_MS=$TIME_MS"
  "OFFSET_MS=$OFFSET_MS"
  "INTERFACE=$INTERFACE"

  "LOCAL_PORT=$LOCAL_PORT"
  "REMOTE_PORT=$REMOTE_PORT"
  "DESTINATION_IP=$DESTINATION_IP"
  "EXCLUDE_IP=$EXCLUDE_IP"
  "EXCLUDE_PORT=$EXCLUDE_PORT"

  "FORCE=$FORCE"
  "IGNORE_PEER_PORT=$IGNORE_PEER_PORT"

  "MIN_HOLD_SECONDS=$MIN_HOLD_SECONDS"
  "MAX_HOLD_SECONDS=$MAX_HOLD_SECONDS"
  # "HOLD_SECONDS=$HOLD_SECONDS"
  "TIMEOUT_PADDING=$TIMEOUT_PADDING"

  "LOG_DIR=$LOG_DIR"
  "CLEANUP=$CLEANUP"
)

# 0) sanity
if [[ ! -x "$HELPER" ]]; then
  echo "ERROR: helper not found or not executable: $HELPER"
  echo "Fix: chmod +x $HELPER"
  exit 1
fi

# 1) install resource configmaps (template/env/script)
bash "$HELPER" install

# 2) set env configmap
bash -x "$HELPER" set "${args[@]}"

# 3) install cron resources (CronJob + RBAC/SA in cron yaml)
bash "$HELPER" install cron

# 4) patch cron parameters
bash "$HELPER" cron set activeDeadlineSeconds="$TOTAL_SECONDS"
bash "$HELPER" cron set schedule="$CRON_SCHEDULE"
# OR:
# bash "$HELPER" cron schedule "$CRON_SCHEDULE"

# 5) enable cron
bash "$HELPER" cron enable

# optional:
# bash "$HELPER" cron resume
# bash "$HELPER" cron status
