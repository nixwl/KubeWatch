#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_disk_fill_helper.sh"

# == Environment Variables ==================================================================================
BLADE_NAME="chaosblade-singlenode-disk-fill-payload"
TARGET_NODE="emanage1"

DISK_PATH="/var/lib/rancher"

# choose ONE (mutually exclusive)
PERCENT="90"
RESERVE_MB="-"
SIZE_MB="-"

RETAIN_HANDLE="false"

MIN_HOLD_SECONDS="900"
MAX_HOLD_SECONDS="1800"
TIMEOUT_PADDING="30"

LOG_DIR="/logs"
CLEANUP="true"

args=(
  "BLADE_NAME=$BLADE_NAME"
  "TARGET_NODE=$TARGET_NODE"
  "CLEANUP=$CLEANUP"

  "DISK_PATH=$DISK_PATH"
  "PERCENT=$PERCENT"
  "RESERVE_MB=$RESERVE_MB"
  "SIZE_MB=$SIZE_MB"
  "RETAIN_HANDLE=$RETAIN_HANDLE"

  "MIN_HOLD_SECONDS=$MIN_HOLD_SECONDS"
  "MAX_HOLD_SECONDS=$MAX_HOLD_SECONDS"
  "TIMEOUT_PADDING=$TIMEOUT_PADDING"
  "LOG_DIR=$LOG_DIR"
)

if [[ ! -x "$HELPER" ]]; then
  echo "ERROR: helper not found or not executable: $HELPER"
  echo "Fix: chmod +x $HELPER"
  exit 1
fi

# 1) install ConfigMaps only
bash "$HELPER" install

# 2) patch env configmap
bash -x "$HELPER" set "${args[@]}"

# 3) install Job prerequisites
bash "$HELPER" install job

# 4) run one job
bash "$HELPER" job run

# 5) tail latest job logs
# bash "$HELPER" job logs last
