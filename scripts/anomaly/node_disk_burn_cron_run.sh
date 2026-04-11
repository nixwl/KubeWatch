#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_disk_burn_helper.sh"

# == Environment Variables ==================================================================================
BLADE_NAME="chaosblade-singlenode-disk-burn-payload"
TARGET_NODE="emanage1"

DISK_PATH="/var/lib/rancher"
READ="true"
WRITE="true"
SIZE="20"

MIN_HOLD_SECONDS="900"
MAX_HOLD_SECONDS="1800"
# HOLD_SECONDS="1800"
TIMEOUT_PADDING="30"

LOG_DIR="/logs"
CLEANUP="true"

# Cron schedule (example: run at minute 30 every 4 hours)
CRON_SCHEDULE="30 */4 * * *"

# activeDeadlineSeconds should be >= HOLD + TIMEOUT_PADDING + 120
# - If HOLD_SECONDS is set: use HOLD_SECONDS
# - Otherwise use MAX_HOLD_SECONDS (worst case)
if [[ -n "${HOLD_SECONDS:-}" && "${HOLD_SECONDS}" != "-" ]]; then
  TOTAL_SECONDS=$(( HOLD_SECONDS + TIMEOUT_PADDING + 120 ))
else
  TOTAL_SECONDS=$(( MAX_HOLD_SECONDS + TIMEOUT_PADDING + 120 ))
fi

args=(
  "BLADE_NAME=$BLADE_NAME"
  "TARGET_NODE=$TARGET_NODE"
  "CLEANUP=$CLEANUP"

  "DISK_PATH=$DISK_PATH"
  "READ=$READ"
  "WRITE=$WRITE"
  "SIZE=$SIZE"

  "MIN_HOLD_SECONDS=$MIN_HOLD_SECONDS"
  "MAX_HOLD_SECONDS=$MAX_HOLD_SECONDS"
  # "HOLD_SECONDS=$HOLD_SECONDS"
  "TIMEOUT_PADDING=$TIMEOUT_PADDING"

  "LOG_DIR=$LOG_DIR"
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

# 3) install cron resources (CronJob + RBAC/SA...)
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