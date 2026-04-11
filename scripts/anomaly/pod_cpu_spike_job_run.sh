#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_cpu_spike_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="zot" # database, zot, wiki, gitea, rt
POD_LABELS="app.kubernetes.io/instance=zot"
# DATABASE
# mysql： statefulset.kubernetes.io/pod-name=mysql8-primary-0
# redis： statefulset.kubernetes.io/pod-name=redis-ha-node-0
# pg：statefulset.kubernetes.io/pod-name=pg-postgresql-primary-0
## zot: app.kubernetes.io/instance=zot
## wiki: app.kubernetes.io/instance=wiki
## gitea： app.kubernetes.io/instance=gitea
## rt： app.kubernetes.io/instance=rt
CONTAINER_NAME="zot"
## DATABASE
# mysql： mysql
# redis： "redis sentinel"
# pg:  postgresql
## zot: zot
## wiki: wiki
## gitea: 
## rt: main

SPIKE_PERCENT="95"
SPIKE_RAMP_SECONDS="5"
SPIKE_MIN_HOLD_SECONDS="120"
SPIKE_MAX_HOLD_SECONDS="240"
SPIKE_TIMEOUT_PADDING="30"
TIMEOUT="86400"

# Use the SELECTOR parameter directly in the set command
args=(
  "TARGET_NS=$TARGET_NS"
  "SELECTOR=$POD_LABELS"
  "SELECTOR_MODE=first"
  "CONTAINER_NAME=$CONTAINER_NAME"
  "SPIKE_PERCENT=$SPIKE_PERCENT"
  "SPIKE_RAMP_SECONDS=$SPIKE_RAMP_SECONDS"
  "SPIKE_MIN_HOLD_SECONDS=$SPIKE_MIN_HOLD_SECONDS"
  "SPIKE_MAX_HOLD_SECONDS=$SPIKE_MAX_HOLD_SECONDS"
  "SPIKE_TIMEOUT_PADDING=$SPIKE_TIMEOUT_PADDING"
  "TIMEOUT=$TIMEOUT" 
)

bash $HELPER install
bash "$HELPER" set "${args[@]}"
bash $HELPER install job
bash $HELPER job run