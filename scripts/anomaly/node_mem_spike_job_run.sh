#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_mem_spike_helper.sh"

# == Environment Variables ==================================================================================
BLADE_NAME="chaosblade-singlenode-mem-spike-payload-master2"
TARGET_NODE="master2"

PERCENT="70"
MAX_MEM_PERCENT="82"
MEM_MODE="ram"
RAMP_SECONDS="30"
MIN_HOLD_SECONDS="150"
MAX_HOLD_SECONDS="300"
TIMEOUT_PADDING="30"
CLEANUP="true"
TIMEOUT="86400"

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
  "TIMEOUT=$TIMEOUT"
)

# 0) sanity
if [[ ! -x "$HELPER" ]]; then
  echo "ERROR: helper not found or not executable: $HELPER"
  echo "Fix: chmod +x $HELPER"
  exit 1
fi

# 1) install ConfigMaps only (template/env/script)
bash "$HELPER" install

# 2) patch env configmap
bash -x "$HELPER" set "${args[@]}"

# 3) install Job prerequisites (SA/CR/CRB...)
bash "$HELPER" install job

# 4) run one job
bash "$HELPER" job run

# 5) tail latest job logs
# bash "$HELPER" job logs last
