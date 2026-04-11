#!/usr/bin/env bash
set -euo pipefail

# == Environment Variables ==================================================================================
# BLADE_NAME: the name of the ChaosBlade instance (ChaosBlade CR name)
# TARGET_NODE: target node name to inject cpu spike
# SPIKE_PERCENT: cpu spike percentage (0-100)
# SPIKE_RAMP_SECONDS: ramp-up seconds before reaching SPIKE_PERCENT (soft start)
# SPIKE_MIN_HOLD_SECONDS: minimum hold seconds for spike
# SPIKE_MAX_HOLD_SECONDS: maximum hold seconds for spike
# SPIKE_TIMEOUT_PADDING: extra seconds added to job activeDeadlineSeconds (safety padding)
# CLEANUP: whether to cleanup ChaosBlade CR after run ("true"/"false")
#
# CRON_SCHEDULE: cron expression for schedule (e.g. "30 */4 * * *")
# TOTAL_SECONDS: activeDeadlineSeconds for CronJob's jobTemplate; should cover:
#   ramp + max_hold + padding (+ small extra buffer)
# ============================================================================================================

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_cpu_spike_helper.sh"

BLADE_NAME="chaosblade-singlenode-cpu-spike-payload"
TARGET_NODE="emanage1"

SPIKE_PERCENT="90"
SPIKE_RAMP_SECONDS="5"
SPIKE_MIN_HOLD_SECONDS="200"
SPIKE_MAX_HOLD_SECONDS="300"
SPIKE_TIMEOUT_PADDING="30"
CLEANUP="true"

# Cron schedule (example: run every 4 hours at minute 30)
CRON_SCHEDULE="30 */4 * * *"

# Compute TOTAL_SECONDS for jobTemplate.activeDeadlineSeconds:
# - worst case: ramp + max_hold + padding + extra_buffer
EXTRA_BUFFER="30"
TOTAL_SECONDS=$(( SPIKE_RAMP_SECONDS + SPIKE_MAX_HOLD_SECONDS + SPIKE_TIMEOUT_PADDING + EXTRA_BUFFER ))

# == Install ConfigMaps ======================================================================================
# install resource configmaps (template/env/script)
bash "$HELPER" install

# == Patch Env ConfigMap =====================================================================================
# HELP: bash node_cpu_spike_helper.sh show
bash -x "$HELPER" set \
  BLADE_NAME="$BLADE_NAME" \
  TARGET_NODE="$TARGET_NODE" \
  SPIKE_PERCENT="$SPIKE_PERCENT" \
  SPIKE_RAMP_SECONDS="$SPIKE_RAMP_SECONDS" \
  SPIKE_MIN_HOLD_SECONDS="$SPIKE_MIN_HOLD_SECONDS" \
  SPIKE_MAX_HOLD_SECONDS="$SPIKE_MAX_HOLD_SECONDS" \
  SPIKE_TIMEOUT_PADDING="$SPIKE_TIMEOUT_PADDING" \
  CLEANUP="$CLEANUP"

# == Install CronJob ==========================================================================================
# install cronjob only (no job prerequisites)
bash "$HELPER" install cron

# == Patch Cron Parameters ====================================================================================
# Set jobTemplate parameters to adapt to the calculated duration
# NOTE: activeDeadlineSeconds is under CronJob.spec.jobTemplate.spec.activeDeadlineSeconds (helper handles this)
bash "$HELPER" cron set activeDeadlineSeconds="$TOTAL_SECONDS"
bash "$HELPER" cron set schedule="$CRON_SCHEDULE"

# Optional recommended cron defaults (if you want)
bash "$HELPER" cron set concurrencyPolicy=Forbid startingDeadlineSeconds=60 successfulJobsHistoryLimit=1 failedJobsHistoryLimit=1
bash "$HELPER" cron set backoffLimit=0 ttlSecondsAfterFinished=3600

# == Enable Cron ==============================================================================================
# Run/enable cron job
# HELP: bash node_cpu_spike_helper.sh cron --help
bash "$HELPER" cron enable
# bash "$HELPER" cron resume

# == Quick Status =============================================================================================
# bash "$HELPER" cron status