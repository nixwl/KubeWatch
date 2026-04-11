#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_mem_high_helper.sh"

# == Environment Variables ================================================================================
BLADE_NAME="chaosblade-singlenode-mem-high-payload-node3"
TARGET_NODE="node3"
PERCENT="75"              # Target memory percentage (e.g. 85)
MAX_MEM_PERCENT="82"      # Random/upper-bound constraint (e.g. 90)
MEM_MODE="ram"            # ram / cache

RAMP_SECONDS="30"         # Ramp duration (seconds)
MIN_HOLD_SECONDS="250"    # Hold minimum (seconds)
MAX_HOLD_SECONDS="350"    # Hold maximum (seconds)
TIMEOUT_PADDING="30"      # Extra timeout padding (seconds)
CLEANUP="true"            # Whether to clean up the ChaosBlade CR when the Job ends
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

# 1) install ConfigMaps only
bash "$HELPER" install

# 2) patch env configmap
bash "$HELPER" set "${args[@]}"

# 3) install Job prerequisites
bash "$HELPER" install job

# 4) run one job
bash "$HELPER" job run

# 5) tail latest job logs
# bash "$HELPER" job logs last