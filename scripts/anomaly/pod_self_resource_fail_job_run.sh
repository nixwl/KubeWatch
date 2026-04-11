#!/usr/bin/env bash
set -euo pipefail

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="${HELPER_DIR}/pod_self_resource_fail_helper.sh"

# == Environment Variables ================================================================================
# target pod selector
TARGET_NS="database"

# choose ONE (preferred): resolve by label -> newest Running pod
POD_LABELS="statefulset.kubernetes.io/pod-name=mysql8-primary-0"
# OR: fixed pod name (set "-" or empty to auto-resolve by label)
POD_NAME=""
# DATABASE
# mysql： statefulset.kubernetes.io/pod-name=mysql8-primary-0
# redis： statefulset.kubernetes.io/pod-name=redis-ha-node-0
# pg：statefulset.kubernetes.io/pod-name=pg-postgresql-primary-0
## zot: app.kubernetes.io/instance=zot
## wiki: app.kubernetes.io/instance=wiki
## gitea： app.kubernetes.io/instance=gitea
## rt： app.kubernetes.io/instance=rt

# optional eviction knobs (choose ONE: EVICT_COUNT or EVICT_PERCENT; use "-" or empty to disable)
EVICT_COUNT=""
EVICT_PERCENT=""
WAITING_TIME="20s"

# fail controls
CLEANUP="true"

# recommended: true for fail (so ChaosBlade CR won't hang forever)
FAIL_ENABLE_TIMEOUT="true"

FAIL_MIN_HOLD_SECONDS="300"
FAIL_MAX_HOLD_SECONDS="500"
FAIL_TIMEOUT_PADDING="30"
# FAIL_HOLD_SECONDS="900"          # optional fixed hold (bypass random [min,max])

# logs
LOG_DIR="/logs"

# ------------------------ helpers ------------------------
trim() { printf '%s' "${1:-}" | tr -d '[:space:]'; }

# Treat "" or "-" as empty
norm_opt() {
  local v
  v="$(trim "${1:-}")"
  if [[ -z "$v" || "$v" == "-" ]]; then
    printf ''
  else
    printf '%s' "$v"
  fi
}

POD_NAME="$(norm_opt "$POD_NAME")"
POD_LABELS="$(norm_opt "$POD_LABELS")"
EVICT_COUNT="$(norm_opt "$EVICT_COUNT")"
EVICT_PERCENT="$(norm_opt "$EVICT_PERCENT")"

# Validate eviction knobs mutual exclusion
if [[ -n "${EVICT_COUNT}" && -n "${EVICT_PERCENT}" ]]; then
  echo "ERROR: EVICT_COUNT and EVICT_PERCENT are mutually exclusive. Choose ONE."
  exit 1
fi

# Resolve POD_NAME dynamically (newest Running pod by label) if empty
if [[ -z "${POD_NAME}" ]]; then
  [[ -n "${POD_LABELS}" ]] || { echo "ERROR: POD_NAME empty and POD_LABELS empty; set at least one."; exit 1; }
  POD_NAME="$(
    kubectl -n "${TARGET_NS}" get pod -l "${POD_LABELS}"       --field-selector=status.phase=Running       --sort-by=.metadata.creationTimestamp       -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'     | tail -n 1
  )"
fi
[[ -n "${POD_NAME}" ]] || { echo "ERROR: cannot resolve POD_NAME (ns=${TARGET_NS} labels=${POD_LABELS})"; exit 1; }

# For helper's normalize_opt logic: pass "-" when disabling a field
evict_count_arg="${EVICT_COUNT:-"-"}"
evict_percent_arg="${EVICT_PERCENT:-"-"}"
pod_labels_arg="${POD_LABELS:-"-"}"

args=(
  "TARGET_NS=${TARGET_NS}"
  "POD_NAME=${POD_NAME}"
  "POD_LABELS=${pod_labels_arg}"

  "EVICT_COUNT=${evict_count_arg}"
  "EVICT_PERCENT=${evict_percent_arg}"
  "WAITING_TIME=${WAITING_TIME}"

  "CLEANUP=${CLEANUP}"

  "FAIL_ENABLE_TIMEOUT=${FAIL_ENABLE_TIMEOUT}"
  "FAIL_MIN_HOLD_SECONDS=${FAIL_MIN_HOLD_SECONDS}"
  "FAIL_MAX_HOLD_SECONDS=${FAIL_MAX_HOLD_SECONDS}"
  "FAIL_TIMEOUT_PADDING=${FAIL_TIMEOUT_PADDING}"
  # "FAIL_HOLD_SECONDS=${FAIL_HOLD_SECONDS}"

  "LOG_DIR=${LOG_DIR}"
)

# ------------------------ run ------------------------
bash "${HELPER}" install
bash "${HELPER}" set "${args[@]}"
bash "${HELPER}" install job
bash "${HELPER}" job run
