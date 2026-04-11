#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_net_delay_helper.sh"

# == Environment Variables ==================================================================================
# Must match net-payload-env.delay.configmap.yaml:
#   TARGET_NODE, BLADE_NAME, CLEANUP,
#   TIME_MS, OFFSET_MS, INTERFACE,
#   LOCAL_PORT, REMOTE_PORT, DESTINATION_IP, EXCLUDE_IP, EXCLUDE_PORT,
#   FORCE, IGNORE_PEER_PORT,
#   MIN_HOLD_SECONDS, MAX_HOLD_SECONDS, (optional) HOLD_SECONDS, TIMEOUT_PADDING,
#   LOG_DIR
#   When EXCLUDE_PORT != '-', LOCAL_PORT / REMOTE_PORT must be '-'

BLADE_NAME="chaosblade-singlenode-net-delay-payload-node2"
TARGET_NODE="node2"

# delay params
TIME_MS="75"
OFFSET_MS="10"
INTERFACE="ens33" # cni0

# optional filters ('-' means unset)
LOCAL_PORT="-"
REMOTE_PORT="-"
DESTINATION_IP="-"
EXCLUDE_IP="-"
EXCLUDE_PORT="22,9090,9100,8080,443"       # Common: exclude the SSH port
TIMEOUT="86400"

# optional flags
FORCE="false"
IGNORE_PEER_PORT="false"

# runtime control
MIN_HOLD_SECONDS="300"
MAX_HOLD_SECONDS="600"
# HOLD_SECONDS="900"     # Optional: fixed hold
TIMEOUT_PADDING="30"

# logs dir (PVC mounted by job yaml)
LOG_DIR="/logs"

CLEANUP="true"

args=(
  "BLADE_NAME=$BLADE_NAME"
  "TARGET_NODE=$TARGET_NODE"
  "TIMEOUT=$TIMEOUT"

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