#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_disk_io_delay_stable_helper.sh"

# == Environment Variables ================================================================================
TARGET_NS="default"
POD_LABELS="app=stress-test"
CONTAINER_NAME="busybox"

# choose ONE: POD_NAME or POD_LABELS
POD_NAME=""          # optional: fixed pod name; empty => resolve by labels

# optional eviction pre-step (use '-' to disable)
EVICT_COUNT="-"      # e.g. "1"
EVICT_PERCENT="-"    # e.g. "50"
WAITING_TIME="-"     # e.g. "20s" "1m"

BLADE_NAME="chaosblade-pod-io-delay-stable-payload"
CLEANUP="true"

# IO delay params (stable)
IO_METHOD="read"         # read / write / open / fsync / rename ...
IO_DELAY_MS="1000"       # hit => delay 1000ms
IO_PERCENT="100"         # hit percent
IO_PATH="/data/conf"     # must be inside injected directory

# runtime control
IO_MIN_HOLD_SECONDS="120"
IO_MAX_HOLD_SECONDS="300"
IO_TIMEOUT_PADDING="30"

# optional fixed hold (bypass random [min,max])
# IO_HOLD_SECONDS="180"

# host mounts / logging
CGROUP_ROOT="/host-sys/fs/cgroup"
LOG_DIR="/logs"

# --- resolve POD_NAME dynamically (newest Running pod by label) ---
if [[ -z "${POD_NAME:-}" ]]; then
  POD_NAME="$(
    kubectl -n "$TARGET_NS" get pod -l "$POD_LABELS" \
      --field-selector=status.phase=Running \
      --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | tail -n 1
  )"
fi
[[ -n "$POD_NAME" ]] || { echo "ERROR: cannot resolve POD_NAME by labels: ns=$TARGET_NS labels=$POD_LABELS"; exit 1; }

args=(
  "TARGET_NS=$TARGET_NS"
  "POD_NAME=$POD_NAME"
  "POD_LABELS=$POD_LABELS"
  "CONTAINER_NAME=$CONTAINER_NAME"

  "EVICT_COUNT=$EVICT_COUNT"
  "EVICT_PERCENT=$EVICT_PERCENT"
  "WAITING_TIME=$WAITING_TIME"

  "BLADE_NAME=$BLADE_NAME"
  "CLEANUP=$CLEANUP"

  "IO_METHOD=$IO_METHOD"
  "IO_DELAY_MS=$IO_DELAY_MS"
  "IO_PERCENT=$IO_PERCENT"
  "IO_PATH=$IO_PATH"

  "IO_MIN_HOLD_SECONDS=$IO_MIN_HOLD_SECONDS"
  "IO_MAX_HOLD_SECONDS=$IO_MAX_HOLD_SECONDS"
  "IO_TIMEOUT_PADDING=$IO_TIMEOUT_PADDING"

  # optional fixed hold
  # "IO_HOLD_SECONDS=$IO_HOLD_SECONDS"

  "CGROUP_ROOT=$CGROUP_ROOT"
  "LOG_DIR=$LOG_DIR"
)

bash $HELPER install
bash "$HELPER" set "${args[@]}"
bash $HELPER install job
bash $HELPER job run