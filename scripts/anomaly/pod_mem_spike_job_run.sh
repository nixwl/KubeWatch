#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="${HELPER_DIR}/pod_mem_spike_helper.sh"
[[ -f "$HELPER" ]] || { echo "ERROR: helper not found: $HELPER"; exit 1; }

CHAOS_NS="${CHAOS_NS:-chaosblade}"

# == Environment Variables ================================================================================

TARGET_NS="wiki"  # database, zot, wiki, gitea, rt

POD_LABELS="app.kubernetes.io/instance=wiki"
# DATABASE
# mysql： statefulset.kubernetes.io/pod-name=mysql8-primary-0
# redis： statefulset.kubernetes.io/pod-name=redis-ha-node-0
# pg：statefulset.kubernetes.io/pod-name=pg-postgresql-primary-0
## zot: app.kubernetes.io/instance=zot
## wiki: app.kubernetes.io/instance=wiki
## gitea： app.kubernetes.io/instance=gitea
## rt： app.kubernetes.io/instance=rt

CONTAINER_NAME="wiki"
## DATABASE
# mysql： mysql
# redis： "redis sentinel"
# pg:  postgresql
## zot: zot
## wiki: wiki
## gitea:
## rt: main

CLEANUP="true"

# mem-spike keys (aligned with helper usage / regular scripts)
SPIKE_PERCENT="95"
SPIKE_RAMP_SECONDS="5"
SPIKE_MIN_HOLD_SECONDS="120"
SPIKE_MAX_HOLD_SECONDS="150"
SPIKE_TIMEOUT_PADDING="30"
# SPIKE_HOLD_SECONDS="60"    # fixed hold (optional)
TIMEOUT="86400"               # override timeout seconds (optional)

MAX_MEM_PERCENT="90"

MEM_MODE="ram"         # ram / cache
MEM_RATE=""            # MB/s (optional)

CGROUP_ROOT="/host-sys/fs/cgroup"
LOG_DIR="/logs"

# Notes:
# 1) Do not parse POD_NAME here; let the helper handle SELECTOR/SELECTOR_MODE (it will write POD_NAME into the env CM)
# 2) An explicit CONTAINER_NAME will be validated; if it doesn't exist, the helper falls back to the first container and writes it back to the CM

args=(
  "TARGET_NS=$TARGET_NS"
  "SELECTOR=$POD_LABELS"
  "SELECTOR_MODE=first"
  "CONTAINER_NAME=$CONTAINER_NAME"

  "CLEANUP=$CLEANUP"

  "SPIKE_PERCENT=$SPIKE_PERCENT"
  "SPIKE_RAMP_SECONDS=$SPIKE_RAMP_SECONDS"
  "SPIKE_MIN_HOLD_SECONDS=$SPIKE_MIN_HOLD_SECONDS"
  "SPIKE_MAX_HOLD_SECONDS=$SPIKE_MAX_HOLD_SECONDS"
  "SPIKE_TIMEOUT_PADDING=$SPIKE_TIMEOUT_PADDING"
  # "SPIKE_HOLD_SECONDS=$SPIKE_HOLD_SECONDS"
  "TIMEOUT=$TIMEOUT"

  "MAX_MEM_PERCENT=$MAX_MEM_PERCENT"

  "MEM_MODE=$MEM_MODE"
  "MEM_RATE=$MEM_RATE"

  "CGROUP_ROOT=$CGROUP_ROOT"
  "LOG_DIR=$LOG_DIR"
)

echo "Apply helper in chaos ns: $CHAOS_NS"
echo "Target workload ns: $TARGET_NS, selector: $POD_LABELS, container: $CONTAINER_NAME"

NS="$CHAOS_NS" bash "$HELPER" install
NS="$CHAOS_NS" bash "$HELPER" set "${args[@]}"
NS="$CHAOS_NS" bash "$HELPER" install job
NS="$CHAOS_NS" bash "$HELPER" job run
# NS="$CHAOS_NS" bash "$HELPER" job logs last
