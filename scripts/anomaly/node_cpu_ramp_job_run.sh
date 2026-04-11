#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/node_cpu_ramp_helper.sh"

# == Environment Variables ================================================================================
BLADE_NAME="chaosblade-singlenode-cpu-ramp-payload-job-master1"
HIGH="100"
LOW="90"
CYCLES="7"
HOLD_SECONDS="60"
RAMP_SECONDS="10"
TARGET_NODE="master1"
CLEANUP="true"

TOTAL_SECONDS=$(( CYCLES * (HOLD_SECONDS + RAMP_SECONDS) + 60 ))
TOTAL_EXPERIMENT_TIME=$(( CYCLES * 2 * (RAMP_SECONDS + HOLD_SECONDS) ))
TIMEOUT=$(( TOTAL_EXPERIMENT_TIME + 300 ))

# install ConfigMaps only
bash $HELPER install

# patch env configmap
bash $HELPER set BLADE_NAME=$BLADE_NAME \
                 HIGH=$HIGH \
                 LOW=$LOW \
                 CYCLES=$CYCLES \
                 HOLD_SECONDS=$HOLD_SECONDS \
                 RAMP_SECONDS=$RAMP_SECONDS \
                 TARGET_NODE=$TARGET_NODE \
                 CLEANUP=$CLEANUP \
                 TIMEOUT=$TIMEOUT

# install Job prerequisites
bash $HELPER install job

# run one job
bash $HELPER job run

# # tail latest job logs
# bash $HELPER job logs last