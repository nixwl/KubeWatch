#!/usr/bin/env bash
set -euo pipefail

# == Environment Variables ==================================================================================
# Parameter names must follow mem-payload-env.spike.configmap.yaml:
HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_mem_spike_helper.sh"

BLADE_NAME="chaosblade-singlenode-mem-spike-payload"
TARGET_NODE="emanage1"

PERCENT="85"
MAX_MEM_PERCENT="90"
MEM_MODE="ram"

RAMP_SECONDS="2"
MIN_HOLD_SECONDS="30"
MAX_HOLD_SECONDS="90"
TIMEOUT_PADDING="30"

CLEANUP="true"

# Cron schedule example:
#   Run at minute 30 every 4 hours
CRON_SCHEDULE="30 */4 * * *"
TOTAL_SECONDS=$(( RAMP_SECONDS + MAX_HOLD_SECONDS + TIMEOUT_PADDING + 60 ))

args=(
  "BLADE_NAME=$BLADE_NAME"
  "TARGET_NODE=$TARGET_NODE"
  "PERCENT=$PERCENT"
  "MAX_MEM_PERCENT=$MAX_MEM_PERCENT"
  "MEM_MODE=$MEM_MODE"
  "RAMP_SECONDS=$RAMP_SECONDS"
  "MIN_HOLD_SECONDS=$MIN_HOLD_SECONDS"
  "MAX_HOLD_SECONDS=$MAX_HOLD_SECONDS"
  "TIMEOUT_PADDING=$TIMEOUT_PADDING"
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

# 3) install cron resources (CronJob + SA/CR/CRB in cron yaml)
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
