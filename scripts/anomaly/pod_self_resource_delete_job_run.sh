#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================================================
# Runner: Pod Self-Resource Delete (ChaosBlade)
# - Purpose: delete one or more target pods (self-resource pod-delete) and keep an observation window (HOLD)
# - Style: follow your existing runner conventions (resolve POD_NAME dynamically, KEY=VALUE args, helper install/set)
#
# Target examples (choose ONE of these selectors):
#   1) POD_NAME (fixed):
#        POD_NAME="mysql8-primary-0"
#   2) POD_LABELS (dynamic resolve newest Running pod by label):
#        POD_LABELS="app.kubernetes.io/instance=gitea"
#
# Reference labels / containers (for your convenience):
# DATABASE
#   mysql: statefulset.kubernetes.io/pod-name=mysql8-primary-0
#   redis: statefulset.kubernetes.io/pod-name=redis-ha-node-0
#   pg:    statefulset.kubernetes.io/pod-name=pg-postgresql-primary-0
# Apps (recommended label selectors):
#   zot :  app.kubernetes.io/instance=zot
#   wiki:  app.kubernetes.io/instance=wiki
#   gitea: app.kubernetes.io/instance=gitea
#   rt  :  app.kubernetes.io/instance=rt
# NOTE: pod-delete does NOT need CONTAINER_NAME.
# ==========================================================================================================

HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
HELPER="$HELPER_DIR/pod_self_resource_delete_helper.sh"

# == Target ================================================================================================
TARGET_NS="database"

# --- choose ONE: POD_NAME or POD_LABELS ---
POD_NAME=""
POD_LABELS="statefulset.kubernetes.io/pod-name=mysql8-primary-0"
# DATABASE
# mysql： statefulset.kubernetes.io/pod-name=mysql8-primary-0
# redis： statefulset.kubernetes.io/pod-name=redis-ha-node-0
# pg：statefulset.kubernetes.io/pod-name=pg-postgresql-primary-0
## zot: app.kubernetes.io/instance=zot
## wiki: app.kubernetes.io/instance=wiki
## gitea： app.kubernetes.io/instance=gitea
## rt： app.kubernetes.io/instance=rt

# == Optional matchers (ChaosBlade eviction knobs) =========================================================
# Choose ONE (leave the other empty or "-")
EVICT_COUNT="1"                       # e.g. 1
EVICT_PERCENT=""                      # e.g. 50
WAITING_TIME="20s"                    # eviction waiting time

# == Runtime controls ======================================================================================
CLEANUP="true"                        # delete ChaosBlade CR after run
LOG_DIR="/logs"

DELETE_MIN_HOLD_SECONDS="120"
DELETE_MAX_HOLD_SECONDS="240"
DELETE_TIMEOUT_PADDING="30"
# DELETE_HOLD_SECONDS="90"            # optional fixed hold (bypass random [min,max])

# One-shot delete: keep false unless you explicitly want ChaosBlade timeout matcher.
DELETE_ENABLE_TIMEOUT="false"

# ----------------------------------------------------------------------------------------------------------
normalize_opt() {
  local v="${1:-}"
  v="$(printf '%s' "$v" | tr -d '[:space:]')"
  if [[ -z "$v" || "$v" == "-" ]]; then
    echo ""
  else
    echo "$v"
  fi
}

POD_NAME="$(normalize_opt "${POD_NAME}")"
POD_LABELS="$(normalize_opt "${POD_LABELS}")"
EVICT_COUNT="$(normalize_opt "${EVICT_COUNT}")"
EVICT_PERCENT="$(normalize_opt "${EVICT_PERCENT}")"
WAITING_TIME="$(normalize_opt "${WAITING_TIME}")"

# --- basic validation: names vs labels ---
if [[ -z "${POD_NAME}" && -z "${POD_LABELS}" ]]; then
  echo "ERROR: POD_NAME empty AND POD_LABELS empty. Set at least one."
  exit 2
fi

# --- mutually exclusive eviction knobs ---
if [[ -n "${EVICT_COUNT}" && -n "${EVICT_PERCENT}" ]]; then
  echo "ERROR: EVICT_COUNT and EVICT_PERCENT are mutually exclusive. Choose ONE."
  exit 2
fi

# --- resolve POD_NAME dynamically (newest Running pod by label) ---
if [[ -z "${POD_NAME}" ]]; then
  POD_NAME="$(
    kubectl -n "${TARGET_NS}" get pod -l "${POD_LABELS}" \
      --field-selector=status.phase=Running \
      --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | tail -n 1
  )"
fi

if [[ -z "${POD_NAME}" ]]; then
  echo "ERROR: cannot resolve POD_NAME (ns=${TARGET_NS} labels='${POD_LABELS}')"
  exit 2
fi

echo "Target resolved: ${TARGET_NS}/${POD_NAME} (labels='${POD_LABELS:-<none>}')"

# == Assemble args =========================================================================================
args=(
  "TARGET_NS=${TARGET_NS}"
  "POD_NAME=${POD_NAME}"

  # keep labels for audit/context (script supports both); use '-' to disable in CM if needed
  "POD_LABELS=${POD_LABELS:-}"

  "CLEANUP=${CLEANUP}"

  # eviction knobs (leave empty to disable)
  "EVICT_COUNT=${EVICT_COUNT:-}"
  "EVICT_PERCENT=${EVICT_PERCENT:-}"
  "WAITING_TIME=${WAITING_TIME:-}"

  # runtime control
  "DELETE_MIN_HOLD_SECONDS=${DELETE_MIN_HOLD_SECONDS}"
  "DELETE_MAX_HOLD_SECONDS=${DELETE_MAX_HOLD_SECONDS}"
  "DELETE_TIMEOUT_PADDING=${DELETE_TIMEOUT_PADDING}"
  # "DELETE_HOLD_SECONDS=${DELETE_HOLD_SECONDS}"

  "DELETE_ENABLE_TIMEOUT=${DELETE_ENABLE_TIMEOUT}"
  "LOG_DIR=${LOG_DIR}"
)

# == Execute ===============================================================================================
bash "${HELPER}" install
bash "${HELPER}" set "${args[@]}"
bash "${HELPER}" install job
bash "${HELPER}" job run

# Optional:
# bash "${HELPER}" job logs last
