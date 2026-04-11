# pod_disk_error_intermit_job_run.sh
#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_disk_io_error_intermit_helper.sh"

# == Environment Variables ================================================================================

# target
TARGET_NS="default"
POD_LABELS="app=stress-test"

# chaosblade
BLADE_NAME="chaosblade-pod-io-error-intermit-payload"
CLEANUP="true"

# io error params
IO_METHOD="read"          # read / write / open / fsync / rename ...
IO_ERRNO="5"              # 5=I/O error；28=No space left on device
IO_PERCENT="100"          # fail window hit ratio (100=always fail)
IO_PATH="/data/conf"      # must be under injected volume path

# intermit windows
IO_FAIL_MIN_HOLD_SECONDS="30"
IO_FAIL_MAX_HOLD_SECONDS="120"
# IO_FAIL_HOLD_SECONDS="60"      # optional: fixed fail window (higher priority)

IO_RECOVER_MIN_SECONDS="30"
IO_RECOVER_MAX_SECONDS="180"
# IO_RECOVER_SECONDS="120"       # optional: fixed recover window (higher priority)

# stop condition (choose ONE)
IO_TOTAL_SECONDS="600"
IO_CYCLES=""

IO_TIMEOUT_PADDING="30"

# optional selectors
EVICT_COUNT=""
EVICT_PERCENT=""
WAITING_TIME=""                  # e.g. "20s"

LOG_DIR="/logs"

# optional: generate I/O during FAIL window to make it observable
IO_GEN_ENABLE="false"            # true/false
IO_GEN_MODE="mixed"              # read | write | mixed
IO_GEN_INTERVAL_MS="200"
IO_GEN_FILE_KB="64"
IO_GEN_CONTAINER=""              # optional: target container; empty => default
IO_GEN_FILENAME="seed.bin"

# --- resolve POD_NAME dynamically (newest Running pod by label) ---
POD_NAME="$(
  kubectl -n "$TARGET_NS" get pod -l "$POD_LABELS" \
    --field-selector=status.phase=Running \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | tail -n 1
)"
[[ -n "$POD_NAME" ]] || { echo "ERROR: cannot resolve POD_NAME by labels: ns=$TARGET_NS labels=$POD_LABELS"; exit 1; }

args=(
  "TARGET_NS=$TARGET_NS"
  "POD_NAME=$POD_NAME"
  "POD_LABELS=$POD_LABELS"

  "BLADE_NAME=$BLADE_NAME"
  "CLEANUP=$CLEANUP"

  "IO_METHOD=$IO_METHOD"
  "IO_ERRNO=$IO_ERRNO"
  "IO_PERCENT=$IO_PERCENT"
  "IO_PATH=$IO_PATH"

  "IO_FAIL_MIN_HOLD_SECONDS=$IO_FAIL_MIN_HOLD_SECONDS"
  "IO_FAIL_MAX_HOLD_SECONDS=$IO_FAIL_MAX_HOLD_SECONDS"
  # "IO_FAIL_HOLD_SECONDS=$IO_FAIL_HOLD_SECONDS"

  "IO_RECOVER_MIN_SECONDS=$IO_RECOVER_MIN_SECONDS"
  "IO_RECOVER_MAX_SECONDS=$IO_RECOVER_MAX_SECONDS"
  # "IO_RECOVER_SECONDS=$IO_RECOVER_SECONDS"

  "IO_TOTAL_SECONDS=$IO_TOTAL_SECONDS"
  "IO_CYCLES=$IO_CYCLES"

  "IO_TIMEOUT_PADDING=$IO_TIMEOUT_PADDING"

  "EVICT_COUNT=$EVICT_COUNT"
  "EVICT_PERCENT=$EVICT_PERCENT"
  "WAITING_TIME=$WAITING_TIME"

  "LOG_DIR=$LOG_DIR"

  "IO_GEN_ENABLE=$IO_GEN_ENABLE"
  "IO_GEN_MODE=$IO_GEN_MODE"
  "IO_GEN_INTERVAL_MS=$IO_GEN_INTERVAL_MS"
  "IO_GEN_FILE_KB=$IO_GEN_FILE_KB"
  "IO_GEN_CONTAINER=$IO_GEN_CONTAINER"
  "IO_GEN_FILENAME=$IO_GEN_FILENAME"
)

bash "$HELPER" install
bash "$HELPER" set "${args[@]}"
bash "$HELPER" install job
bash "$HELPER" job run