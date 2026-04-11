#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_cpu_spike_helper.sh"

# == Environment Variables ================================================================================
BLADE_NAME="chaosblade-singlenode-cpu-spike-payload-master2"
TARGET_NODE="master2"
SPIKE_PERCENT="100"
SPIKE_RAMP_SECONDS="5"
SPIKE_MIN_HOLD_SECONDS="100"
SPIKE_MAX_HOLD_SECONDS="300"
SPIKE_TIMEOUT_PADDING="30"
TIMEOUT="86400"
CLEANUP="true"

args=(
  "BLADE_NAME=$BLADE_NAME"
  "SPIKE_PERCENT=$SPIKE_PERCENT"
  "SPIKE_RAMP_SECONDS=$SPIKE_RAMP_SECONDS"
  "SPIKE_MIN_HOLD_SECONDS=$SPIKE_MIN_HOLD_SECONDS"
  "SPIKE_MAX_HOLD_SECONDS=$SPIKE_MAX_HOLD_SECONDS"
  "SPIKE_TIMEOUT_PADDING=$SPIKE_TIMEOUT_PADDING"
  "TARGET_NODE=$TARGET_NODE"
  "CLEANUP=$CLEANUP"
  "TIMEOUT=$TIMEOUT"
)

# install ConfigMaps only
bash $HELPER install

# patch env configmap
bash "$HELPER" set "${args[@]}"

# install Job prerequisites
bash $HELPER install job

# run one job
bash $HELPER job run

# # tail latest job logs
# bash $HELPER job logs last