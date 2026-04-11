#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_disk_burn_helper.sh"

# == Environment Variables ==================================================================================
# Parameter names must match disk-payload-env.burn.configmap.yaml:
#   TARGET_NODE, BLADE_NAME, CLEANUP,
#   DISK_PATH, READ, WRITE, SIZE,
#   MIN_HOLD_SECONDS, MAX_HOLD_SECONDS, (optional) HOLD_SECONDS,
#   TIMEOUT_PADDING, LOG_DIR

BLADE_NAME="chaosblade-singlenode-disk-burn-payload-rw-master2"
TARGET_NODE="master2"
DISK_PATH="/var/lib/rancher"
READ="true"
WRITE="true"
SIZE="5"               # io block size (int)
MIN_HOLD_SECONDS="300"
MAX_HOLD_SECONDS="400"
# HOLD_SECONDS="1800"     # OPT: Fixed hold
TIMEOUT_PADDING="30"

LOG_DIR="/logs"
CLEANUP="true"
TIMEOUT="86400" 

args=(
  "BLADE_NAME=$BLADE_NAME"
  "TARGET_NODE=$TARGET_NODE"
  "CLEANUP=$CLEANUP"
  "TIMEOUT=$TIMEOUT"

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

# 1) install ConfigMaps only (template/env/script)
bash "$HELPER" install

# 2) patch env configmap
# HELP: bash "$HELPER" show
bash -x "$HELPER" set "${args[@]}"

# 3) install Job prerequisites (SA/CR/CRB...)
bash "$HELPER" install job

# 4) run one job
bash "$HELPER" job run

# 5) tail latest job logs
# bash "$HELPER" job logs last