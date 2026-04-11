#!/usr/bin/env bash
set -euo pipefail

# == Environment Variables ==================================================================================
# BLADE_NAME: the name of the ChaosBlade instance
# TARGET_NODE: the target node name (match template "names" selector)
# PERCENT: target memory usage percent
# MAX_MEM_PERCENT: upper bound / clamp for percent randomization (if script uses)
# MEM_MODE: memory load mode (e.g. ram/cache, depending on your script/template support)
# RAMP_SECONDS: ramp duration seconds
# MIN_HOLD_SECONDS/MAX_HOLD_SECONDS: hold window (random range)
# TIMEOUT_PADDING: extra seconds padding for job timeout
# CLEANUP: whether to cleanup ChaosBlade CR after run

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_mem_high_helper.sh"

BLADE_NAME="chaosblade-singlenode-mem-high-payload"
TARGET_NODE="emanage1"

PERCENT="85"
MAX_MEM_PERCENT="90"
MEM_MODE="ram"

RAMP_SECONDS="60"
MIN_HOLD_SECONDS="300"
MAX_HOLD_SECONDS="600"
TIMEOUT_PADDING="30"
CLEANUP="true"

# Cron schedule (example: every 4 hours at minute 30)
CRON_SCHEDULE="30 */4 * * *"

# Use worst-case duration for CronJob activeDeadlineSeconds:
# max hold + ramp + padding + extra buffer(60s)
TOTAL_SECONDS=$(( MAX_HOLD_SECONDS + RAMP_SECONDS + TIMEOUT_PADDING + 60 ))

# 0) sanity
if [[ ! -x "$HELPER" ]]; then
  echo "ERROR: helper not found or not executable: $HELPER"
  echo "Fix: chmod +x $HELPER"
  exit 1
fi

# 1) install resource configmaps (template/env/script)
bash "$HELPER" install

# 2) set envs configmap
# HELP: bash "$HELPER" show
bash -x "$HELPER" set \
  BLADE_NAME="$BLADE_NAME" \
  TARGET_NODE="$TARGET_NODE" \
  PERCENT="$PERCENT" \
  MAX_MEM_PERCENT="$MAX_MEM_PERCENT" \
  MEM_MODE="$MEM_MODE" \
  RAMP_SECONDS="$RAMP_SECONDS" \
  MIN_HOLD_SECONDS="$MIN_HOLD_SECONDS" \
  MAX_HOLD_SECONDS="$MAX_HOLD_SECONDS" \
  TIMEOUT_PADDING="$TIMEOUT_PADDING" \
  CLEANUP="$CLEANUP"

# 3) install cron resources (CronJob + its RBAC/SA if defined in CRON_YAML)
bash "$HELPER" install cron

# 4) set cron parameters to adapt to the calculated duration
bash "$HELPER" cron set activeDeadlineSeconds="$TOTAL_SECONDS"
bash "$HELPER" cron set schedule="$CRON_SCHEDULE"
# OR:
# bash "$HELPER" cron schedule "$CRON_SCHEDULE"

# 5) enable cron (apply cron yaml)
# HELP: bash "$HELPER" cron --help
bash "$HELPER" cron enable

# optional: ensure it's running (if it was previously suspended)
# bash "$HELPER" cron resume