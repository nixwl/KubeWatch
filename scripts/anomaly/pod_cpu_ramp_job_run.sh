#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_cpu_ramp_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="gitea" # database, zot, wiki, gitea, rt
POD_LABELS="app.kubernetes.io/instance=gitea"
# DATABASE
# mysql： statefulset.kubernetes.io/pod-name=mysql8-primary-0
# redis： statefulset.kubernetes.io/pod-name=redis-ha-node-0
# pg：statefulset.kubernetes.io/pod-name=pg-postgresql-primary-0
## zot: app.kubernetes.io/instance=zot
## wiki: app.kubernetes.io/instance=wiki
## gitea： app.kubernetes.io/instance=gitea
## rt： app.kubernetes.io/instance=rt
CONTAINER_NAME="gitea"
## DATABASE
# mysql： mysql
# redis： "redis sentinel"
# pg:  postgresql
## zot: zot
## wiki: wiki
## rt: main

HIGH="95"
LOW="85"
RAMP_SECONDS="30"
HOLD_SECONDS="60"
CYCLES="8"
TIMEOUT="86400"

# Use the set command and include the SELECTOR parameter
args=(
  "TARGET_NS=$TARGET_NS"
  "SELECTOR=$POD_LABELS"
  "SELECTOR_MODE=first"
  "CONTAINER_NAME=$CONTAINER_NAME"
  "HIGH=$HIGH"
  "LOW=$LOW"
  "RAMP_SECONDS=$RAMP_SECONDS"
  "HOLD_SECONDS=$HOLD_SECONDS"
  "CYCLES=$CYCLES"
  "TIMEOUT=$TIMEOUT" 
)

bash $HELPER install
bash "$HELPER" set "${args[@]}"
bash $HELPER install job
bash $HELPER job run