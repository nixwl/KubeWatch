#!/usr/bin/env bash
set -euo pipefail

# ========= basic =========
DIR="/data/nfs-conf/chaosblade/job/pod/mem/spike"
NS="${NS:-chaosblade}"

TEMPLATE_YAML="${TEMPLATE_YAML:-$DIR/mem-payload-template.pod.spike.yaml}"
ENV_YAML="${ENV_YAML:-$DIR/mem-payload-env.pod.spike.configmap.yaml}"
SCRIPT_YAML="${SCRIPT_YAML:-$DIR/mem-payload-script.pod.spike.configmap.yaml}"
CRON_YAML="${CRON_YAML:-$DIR/mem-payload.pod.spike.cron.yaml}"
JOB_YAML="${JOB_YAML:-$DIR/mem-payload.pod.spike.job.yaml}"

ENV_CM_NAME="${ENV_CM_NAME:-mem-payload-env-pod-spike-configmap}"
CRON_NAME="${CRON_NAME:-mem-payload-pod-spike-cron}"
JOB_APP_LABEL="${JOB_APP_LABEL:-mem-payload-pod-spike}"

# If ENV_OVERWRITE=false (default), and env CM already exists, we do NOT apply ENV_YAML again.
# This prevents "kubectl apply" from overwriting runtime patched values (kubectl patch).
ENV_OVERWRITE="${ENV_OVERWRITE:-false}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1"; exit 1; }; }
need kubectl
need awk
need sed
need tail
need tr
need head
need wc
need grep

# ========= help =========
usage() {
  cat <<EOF
Usage:
  $0 --help

  # install modes (split responsibilities)
  $0 install                 # install ConfigMaps only (template/env/script)
  $0 install job             # install Job prerequisites only (SA/CR/CRB...) - NO ConfigMaps/NO Cron
  $0 install cron            # install Cron resources (SA/CR/CRB/CronJob) - NO ConfigMaps/NO Job prereqs
  $0 install all             # install ConfigMaps + Job prerequisites + Cron resources

  $0 uninstall               # delete CronJob + Jobs + Pods + prereqs + ConfigMaps (best-effort)

  $0 cron  <subcmd> [args...]
  $0 job   <subcmd> [args...]

  $0 set   KEY=VALUE [KEY=VALUE ...]    # patch env configmap data (supports SELECTOR)
  $0 select <label-selector> [namespace] [mode]  # select pod by label and set TARGET_NS/POD_NAME/CONTAINER_NAME
  $0 show                               # show env + cron + jobs + blades
  $0 stop                               # delete current ChaosBlade CR by BLADE_NAME

Quick start (recommended):
  # 1) install base configmaps
  $0 install

  # 2) patch runtime env (overrides values in ENV_YAML)
  # Option A: specify the Pod name directly
  $0 set TARGET_NS=default POD_NAME=xxx CONTAINER_NAME=app

  # Option B: automatically choose a Pod via label selector (new convention)
  #   - SELECTOR：label selector
  #   - SELECTOR_MODE: newest|first|random (default: newest)
  #   - If CONTAINER_NAME is explicitly provided: validate it first; if it does not exist, fall back to the first container and write it back to the CM
  $0 set TARGET_NS=default SELECTOR="app=stress-test" SELECTOR_MODE=newest CONTAINER_NAME=busybox

  # spike params
  $0 set SPIKE_PERCENT=85 MAX_MEM_PERCENT=90
  $0 set SPIKE_RAMP_SECONDS=2
  $0 set SPIKE_MIN_HOLD_SECONDS=30 SPIKE_MAX_HOLD_SECONDS=90
  $0 set SPIKE_TIMEOUT_PADDING=30
  # optional:
  # $0 set SPIKE_HOLD_SECONDS=60        # fixed hold (bypass random [min,max])
  # $0 set TIMEOUT=120                  # override timeout seconds (optional)

  # optional tuning
  # $0 set MEM_MODE=ram                 # ram/cache
  # $0 set MEM_RATE=1024                # MB/s (ram only); empty => auto(best-effort)
  # $0 set CGROUP_ROOT=/host-sys/fs/cgroup LOG_DIR=/logs CLEANUP=true

  # 3) install job prerequisites and run once
  $0 install job
  $0 job run
  $0 job logs last

  # 4) install cron (only after ConfigMaps exist)
  $0 install cron
  $0 cron resume
  $0 cron status

Env override:
  NS=chaosblade DIR=... TEMPLATE_YAML=... ENV_YAML=... SCRIPT_YAML=... CRON_YAML=... JOB_YAML=...
  ENV_CM_NAME=... CRON_NAME=... JOB_APP_LABEL=...
  ENV_OVERWRITE=true|false   (force re-apply ENV_YAML even if CM exists)
EOF
}

usage_cron() {
  cat <<EOF
Usage:
  $0 cron <subcmd> [args...]

Subcmd:
  enable                   Apply cron YAML (create/update Cron resources)
  delete                   Delete cron YAML resources
  suspend                  Patch CronJob spec.suspend=true
  resume                   Patch CronJob spec.suspend=false
  schedule "<cron expr>"   Patch CronJob spec.schedule
  set KEY=VALUE [...]      Patch CronJob fields (policy/history/deadlines/jobTemplate)
  status                   Show CronJob + recent Jobs
  --help                   Show this help

cron set: supported keys
  schedule=<expr>                  (string)
  suspend=true|false               (bool)
  concurrencyPolicy=Allow|Forbid|Replace
  startingDeadlineSeconds=<int>
  successfulJobsHistoryLimit=<int>
  failedJobsHistoryLimit=<int>

  backoffLimit=<int>               (jobTemplate.spec)
  activeDeadlineSeconds=<int>      (jobTemplate.spec)
  ttlSecondsAfterFinished=<int>    (jobTemplate.spec)
EOF
}

usage_job() {
  cat <<EOF
Usage:
  $0 job <subcmd> [args...]

Subcmd:
  run                              Apply prerequisites then create one Job run (generateName)
  delete <jobName>                 Delete a Job by name
  status                           List Jobs filtered by label app=${JOB_APP_LABEL}
  logs [last|<jobName>]            Show logs from container "runner" (default: last)
  set [last|<jobName>] KEY=VALUE   Patch a Job (default target: last)
  --help                           Show this help

job set: supported keys
  backoffLimit=<int>
  activeDeadlineSeconds=<int>
  ttlSecondsAfterFinished=<int>
  parallelism=<int>
  completions=<int>

Notes:
  - Some Job fields are immutable after creation (especially spec.template.*).
EOF
}

# ========= helpers =========
kapply()  { kubectl apply -f "$1"; }
kdelete() { kubectl delete -f "$1" --ignore-not-found; }

# From multi-doc YAML extract the doc of a given kind (no yq dependency)
extract_kind() {
  local file="$1" want="$2"
  awk -v WANT="$want" '
    function flush() {
      if (doc != "" && kind == WANT) {
        print "---"
        print doc
      }
      doc=""; kind=""
    }
    /^---[ \t]*$/ { flush(); next }
    {
      doc = doc $0 "\n"
      if ($1=="kind:" && kind=="") kind=$2
    }
    END { flush() }
  ' "$file"
}

# Extract docs where kind != NOTWANT
extract_not_kind() {
  local file="$1" notwant="$2"
  awk -v NOTWANT="$notwant" '
    function flush() {
      if (doc != "" && kind != NOTWANT) {
        print "---"
        print doc
      }
      doc=""; kind=""
    }
    /^---[ \t]*$/ { flush(); next }
    {
      doc = doc $0 "\n"
      if ($1=="kind:" && kind=="") kind=$2
    }
    END { flush() }
  ' "$file"
}

# Delete jobs whose names start with a prefix (no grep/xargs dependency)
delete_jobs_by_prefix() {
  local prefix="$1"
  [[ -n "$prefix" ]] || return 0

  kubectl -n "$NS" get job -o name 2>/dev/null \
    | sed 's#job.batch/##' \
    | awk -v p="$prefix" 'index($0,p)==1 {print $0}' \
    | while read -r j; do
        [[ -n "$j" ]] || continue
        kubectl -n "$NS" delete job "$j" --ignore-not-found || true
      done
}

# Delete pods whose names start with a prefix (for orphan pods, just in case)
delete_pods_by_prefix() {
  local prefix="$1"
  [[ -n "$prefix" ]] || return 0

  kubectl -n "$NS" get pod -o name 2>/dev/null \
    | sed 's#pod/##' \
    | awk -v p="$prefix" 'index($0,p)==1 {print $0}' \
    | while read -r pnm; do
        [[ -n "$pnm" ]] || continue
        kubectl -n "$NS" delete pod "$pnm" --ignore-not-found || true
      done
}

cm_exists() {
  kubectl -n "$NS" get configmap "$ENV_CM_NAME" >/dev/null 2>&1
}

apply_configmaps() {
  echo "Apply ConfigMaps (template/env/script)..."
  kapply "$TEMPLATE_YAML"

  if [[ "$ENV_OVERWRITE" == "true" ]]; then
    kapply "$ENV_YAML"
  else
    if cm_exists; then
      echo "Skip ENV_YAML apply (env CM exists, ENV_OVERWRITE=false): $NS/$ENV_CM_NAME"
      echo "Hint: use '$0 set KEY=VALUE ...' or ENV_OVERWRITE=true $0 install"
    else
      kapply "$ENV_YAML"
    fi
  fi

  kapply "$SCRIPT_YAML"
}

apply_job_prereqs() {
  echo "Apply Job prerequisites (SA/CR/CRB...) from $JOB_YAML ..."
  extract_not_kind "$JOB_YAML" "Job" | kubectl apply -f -
}

apply_cron() {
  echo "Apply Cron resources from $CRON_YAML ..."
  kapply "$CRON_YAML"
}

# ========= selector + container rules (aligned with the mem-high rules above) =========
get_pod_by_selector() {
  local namespace="$1"
  local selector="$2"
  local mode="${3:-newest}"  # newest|first|random

  local pods=""
  pods="$(kubectl -n "$namespace" get pod -l "$selector" \
    --field-selector=status.phase=Running \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)"

  if [[ -z "${pods// }" ]]; then
    pods="$(kubectl -n "$namespace" get pod -l "$selector" \
      --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)"
  fi

  [[ -n "${pods// }" ]] || { echo "ERROR: cannot resolve pod by selector: ns=$namespace selector=$selector"; return 1; }

  local pod_name=""
  case "$mode" in
    newest) pod_name="$(printf '%s\n' "$pods" | tail -n 1)" ;;
    first)  pod_name="$(printf '%s\n' "$pods" | head -n 1)" ;;
    random)
      local n line
      n="$(printf '%s\n' "$pods" | wc -l | tr -d ' ')"
      line=$((RANDOM % n + 1))
      pod_name="$(printf '%s\n' "$pods" | sed -n "${line}p")"
      ;;
    *)
      echo "ERROR: unknown SELECTOR_MODE: $mode (use newest|first|random)" >&2
      return 1
      ;;
  esac

  [[ -n "${pod_name// }" ]] || { echo "ERROR: selector mode resolved empty pod"; return 1; }
  printf '%s' "$pod_name"
}

list_containers_of_pod() {
  local namespace="$1" pod="$2"
  kubectl -n "$namespace" get pod "$pod" \
    -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' 2>/dev/null || true
}

container_exists_in_pod() {
  local namespace="$1" pod="$2" cname="$3"
  [[ -n "${cname// }" ]] || return 1
  list_containers_of_pod "$namespace" "$pod" | grep -Fxq "$cname"
}

first_container_of_pod() {
  local namespace="$1" pod="$2"
  kubectl -n "$namespace" get pod "$pod" -o jsonpath='{.spec.containers[0].name}' 2>/dev/null || true
}

# patch env CM：./pod_mem_spike_helper.sh set SPIKE_PERCENT=85 ...
# New convention:
#   - Support SELECTOR / SELECTOR_MODE to resolve POD_NAME automatically and write it to the CM
#   - If CONTAINER_NAME is explicitly provided: validate it first; if it does not exist, fall back to the first container and write it back to the CM
cm_set() {
  local selector="" selector_mode="newest"

  local target_ns="" pod_name="" container_name=""
  local has_target_ns=0 has_pod_name=0 has_container_name=0

  local new_args=()
  local kv

  for kv in "$@"; do
    if [[ "$kv" == SELECTOR=* ]]; then
      selector="${kv#SELECTOR=}"
      continue
    elif [[ "$kv" == SELECTOR_MODE=* ]]; then
      selector_mode="${kv#SELECTOR_MODE=}"
      continue
    fi

    [[ "$kv" == *"="* ]] || { echo "ERROR: invalid kv: $kv (need KEY=VALUE)"; exit 1; }

    if [[ "$kv" == TARGET_NS=* ]]; then target_ns="${kv#TARGET_NS=}"; has_target_ns=1; fi
    if [[ "$kv" == POD_NAME=* ]]; then pod_name="${kv#POD_NAME=}"; has_pod_name=1; fi
    if [[ "$kv" == CONTAINER_NAME=* ]]; then
      container_name="${kv#CONTAINER_NAME=}"
      # Container names must not contain whitespace; trim/normalize here to avoid validation failures from hidden spaces
      container_name="$(printf '%s' "$container_name" | tr -d '[:space:]')"
      has_container_name=1
      kv="CONTAINER_NAME=$container_name"
    fi

    new_args+=("$kv")
  done

  # If TARGET_NS is not explicitly provided: try to read it from the CM, otherwise default to "default"
  if [[ $has_target_ns -eq 0 ]]; then
    target_ns="$(get_env_value TARGET_NS)"
    target_ns="${target_ns:-default}"
  fi

  # If POD_NAME is missing but SELECTOR is provided: resolve POD_NAME automatically and write it back
  if [[ $has_pod_name -eq 0 && -n "${selector// }" ]]; then
    pod_name="$(get_pod_by_selector "$target_ns" "$selector" "$selector_mode")" || exit 1
    new_args+=("POD_NAME=$pod_name")
    has_pod_name=1
  fi

  # Container name rules (aligned with your earlier requirements):
  #   - If CONTAINER_NAME is explicitly provided: validate it first; if it does not exist, fall back to the first container (and overwrite the CM)
  #   - If CONTAINER_NAME is not provided: use the first container directly
  if [[ $has_pod_name -eq 1 ]]; then
    local first=""
    first="$(first_container_of_pod "$target_ns" "$pod_name")"

    if [[ $has_container_name -eq 1 && -n "${container_name// }" ]]; then
      if ! container_exists_in_pod "$target_ns" "$pod_name" "$container_name"; then
        echo "WARN: explicit CONTAINER_NAME not found: ${container_name} (pod=${target_ns}/${pod_name})"
        echo "HINT: containers in pod are:"
        list_containers_of_pod "$target_ns" "$pod_name" || true

        if [[ -n "${first// }" ]]; then
          container_name="$first"
          echo "WARN: fallback to first container: ${container_name}"

          # Overwrite the existing CONTAINER_NAME=...
          local tmp=() x
          for x in "${new_args[@]}"; do
            [[ "$x" == CONTAINER_NAME=* ]] && continue
            tmp+=("$x")
          done
          tmp+=("CONTAINER_NAME=$container_name")
          new_args=("${tmp[@]}")
        else
          echo "ERROR: cannot determine first container from pod spec" >&2
          exit 1
        fi
      fi
    else
      if [[ -n "${first// }" ]]; then
        new_args+=("CONTAINER_NAME=$first")
      else
        echo "ERROR: cannot determine first container from pod spec" >&2
        exit 1
      fi
    fi
  fi

  local patch='{"data":{'
  local first=1
  for kv in "${new_args[@]}"; do
    [[ "$kv" == *"="* ]] || { echo "ERROR: invalid kv in patch: $kv"; exit 1; }
    local k="${kv%%=*}"
    local v="${kv#*=}"
    v="${v//\\/\\\\}"; v="${v//\"/\\\"}"
    if [[ $first -eq 0 ]]; then patch+=','; fi
    patch+="\"$k\":\"$v\""
    first=0
  done
  patch+='}}'
  kubectl -n "$NS" patch configmap "$ENV_CM_NAME" --type merge -p "$patch"
}

get_env_value() {
  local key="$1"
  kubectl -n "$NS" get cm "$ENV_CM_NAME" -o "jsonpath={.data.${key}}" 2>/dev/null || true
}

# ---------- JSON helpers (small, sufficient) ----------
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

json_value() {
  local v="$1"
  if [[ "$v" =~ ^(true|false)$ ]]; then
    printf '%s' "$v"
  elif [[ "$v" =~ ^-?[0-9]+$ ]]; then
    printf '%s' "$v"
  else
    printf '"%s"' "$(json_escape "$v")"
  fi
}

# cron set KEY=VALUE ... (patch CronJob selected fields)
cron_set() {
  [[ $# -ge 1 ]] || { echo "ERROR: cron set needs KEY=VALUE ..."; exit 1; }

  local schedule="" suspend="" concurrencyPolicy="" startingDeadlineSeconds=""
  local successfulJobsHistoryLimit="" failedJobsHistoryLimit=""
  local backoffLimit="" activeDeadlineSeconds="" ttlSecondsAfterFinished=""

  local kv k v ku
  for kv in "$@"; do
    [[ "$kv" == *"="* ]] || { echo "ERROR: invalid kv: $kv (need KEY=VALUE)"; exit 1; }
    k="${kv%%=*}"
    v="${kv#*=}"
    ku="$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')"

    case "$ku" in
      SCHEDULE) schedule="$v" ;;
      SUSPEND)  suspend="$v" ;;

      CONCURRENCY_POLICY|CONCURRENCYPOLICY) concurrencyPolicy="$v" ;;
      STARTING_DEADLINE_SECONDS|STARTINGDEADLINESECONDS) startingDeadlineSeconds="$v" ;;
      SUCCESSFUL_JOBS_HISTORY_LIMIT|SUCCESSFULJOBSHISTORYLIMIT) successfulJobsHistoryLimit="$v" ;;
      FAILED_JOBS_HISTORY_LIMIT|FAILEDJOBSHISTORYLIMIT) failedJobsHistoryLimit="$v" ;;

      BACKOFF_LIMIT|BACKOFFLIMIT) backoffLimit="$v" ;;
      ACTIVE_DEADLINE_SECONDS|ACTIVEDEADLINESECONDS) activeDeadlineSeconds="$v" ;;
      TTL_SECONDS_AFTER_FINISHED|TTLSECONDSAFTERFINISHED) ttlSecondsAfterFinished="$v" ;;

      *)
        echo "ERROR: unknown cron field: $k"
        echo "Allowed keys:"
        echo "  schedule, suspend, concurrencyPolicy, startingDeadlineSeconds,"
        echo "  successfulJobsHistoryLimit, failedJobsHistoryLimit,"
        echo "  backoffLimit, activeDeadlineSeconds, ttlSecondsAfterFinished"
        exit 1
        ;;
    esac
  done

  local patch='{"spec":{'
  local first=1

  add_spec_field() {
    local key="$1" val="$2"
    [[ -n "$val" ]] || return 0
    if [[ $first -eq 0 ]]; then patch+=','; fi
    patch+="\"$key\":$(json_value "$val")"
    first=0
  }

  add_spec_field "schedule" "$schedule"
  add_spec_field "suspend" "$suspend"
  add_spec_field "concurrencyPolicy" "$concurrencyPolicy"
  add_spec_field "startingDeadlineSeconds" "$startingDeadlineSeconds"
  add_spec_field "successfulJobsHistoryLimit" "$successfulJobsHistoryLimit"
  add_spec_field "failedJobsHistoryLimit" "$failedJobsHistoryLimit"

  local jt=''
  local jt_first=1

  add_jt_field() {
    local key="$1" val="$2"
    [[ -n "$val" ]] || return 0
    if [[ $jt_first -eq 0 ]]; then jt+=','; fi
    jt+="\"$key\":$(json_value "$val")"
    jt_first=0
  }

  add_jt_field "backoffLimit" "$backoffLimit"
  add_jt_field "activeDeadlineSeconds" "$activeDeadlineSeconds"
  add_jt_field "ttlSecondsAfterFinished" "$ttlSecondsAfterFinished"

  if [[ -n "$jt" ]]; then
    if [[ $first -eq 0 ]]; then patch+=','; fi
    patch+="\"jobTemplate\":{\"spec\":{$jt}}"
    first=0
  fi

  patch+='}}'

  echo "Patching CronJob $NS/$CRON_NAME ..."
  kubectl -n "$NS" patch cronjob "$CRON_NAME" --type merge -p "$patch"
}

latest_job_name() {
  kubectl -n "$NS" get jobs -l "app=${JOB_APP_LABEL}" --sort-by=.metadata.creationTimestamp -o name 2>/dev/null \
    | tail -n 1 | sed 's#job.batch/##'
}

# job set [last|<jobName>] KEY=VALUE ...  (patch a Job's spec fields)
job_set() {
  [[ $# -ge 1 ]] || { echo "ERROR: job set needs KEY=VALUE ... (or: job set <jobName|last> KEY=VALUE ...)"; exit 1; }

  local target
  target="${1:-last}"

  if [[ "$target" == *"="* ]]; then
    target="last"
  else
    shift || true
  fi

  local jn
  if [[ "$target" == "last" ]]; then
    jn="$(latest_job_name)"
    [[ -n "$jn" ]] || { echo "No jobs found with label app=${JOB_APP_LABEL}"; exit 1; }
  else
    jn="$target"
  fi

  [[ $# -ge 1 ]] || { echo "ERROR: job set needs KEY=VALUE ..."; exit 1; }

  local backoffLimit="" activeDeadlineSeconds="" ttlSecondsAfterFinished=""
  local parallelism="" completions=""

  local kv k v ku
  for kv in "$@"; do
    [[ "$kv" == *"="* ]] || { echo "ERROR: invalid kv: $kv (need KEY=VALUE)"; exit 1; }
    k="${kv%%=*}"
    v="${kv#*=}"
    ku="$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')"

    case "$ku" in
      BACKOFF_LIMIT|BACKOFFLIMIT) backoffLimit="$v" ;;
      ACTIVE_DEADLINE_SECONDS|ACTIVEDEADLINESECONDS) activeDeadlineSeconds="$v" ;;
      TTL_SECONDS_AFTER_FINISHED|TTLSECONDSAFTERFINISHED) ttlSecondsAfterFinished="$v" ;;
      PARALLELISM) parallelism="$v" ;;
      COMPLETIONS) completions="$v" ;;
      *)
        echo "ERROR: unknown job field: $k"
        echo "Allowed keys:"
        echo "  backoffLimit, activeDeadlineSeconds, ttlSecondsAfterFinished, parallelism, completions"
        exit 1
        ;;
    esac
  done

  local patch='{"spec":{'
  local first=1

  add_job_field() {
    local key="$1" val="$2"
    [[ -n "$val" ]] || return 0
    if [[ $first -eq 0 ]]; then patch+=','; fi
    patch+="\"$key\":$(json_value "$val")"
    first=0
  }

  add_job_field "backoffLimit" "$backoffLimit"
  add_job_field "activeDeadlineSeconds" "$activeDeadlineSeconds"
  add_job_field "ttlSecondsAfterFinished" "$ttlSecondsAfterFinished"
  add_job_field "parallelism" "$parallelism"
  add_job_field "completions" "$completions"

  patch+='}}'

  echo "Patching Job $NS/$jn ..."
  kubectl -n "$NS" patch job "$jn" --type merge -p "$patch"
}

# Determine ChaosBlade CRD scope to avoid namespace warning when deleting
chaosblade_scope() {
  kubectl get crd chaosblades.chaosblade.io -o jsonpath='{.spec.scope}' 2>/dev/null || true
}

stop_blade() {
  local blade scope
  blade="$(get_env_value BLADE_NAME)"
  if [[ -z "${blade}" ]]; then
    echo "WARN: cannot read BLADE_NAME from cm/$ENV_CM_NAME"
    return 0
  fi

  scope="$(chaosblade_scope)"
  echo "Stopping ChaosBlade CR: ${blade} (scope=${scope:-unknown})"

  if [[ "$scope" == "Cluster" ]]; then
    kubectl delete chaosblades.chaosblade.io "$blade" --ignore-not-found
  else
    kubectl -n "$NS" delete chaosblades.chaosblade.io "$blade" --ignore-not-found
  fi
}

# ========= select command (optional: use a selector to write to the CM in one step) =========
select_pod_by_label() {
  local selector="$1"
  local namespace="${2:-}"
  local mode="${3:-newest}"

  if [[ -z "$namespace" ]]; then
    namespace="$(get_env_value TARGET_NS)"
    namespace="${namespace:-default}"
  fi

  local pod
  pod="$(get_pod_by_selector "$namespace" "$selector" "$mode")" || exit 1

  local first
  first="$(first_container_of_pod "$namespace" "$pod")"
  [[ -n "${first// }" ]] || { echo "ERROR: cannot determine first container"; exit 1; }

  echo "select: ns=$namespace selector='$selector' mode=$mode => pod=$pod container(first)=$first"
  cm_set "TARGET_NS=$namespace" "POD_NAME=$pod" "CONTAINER_NAME=$first"
}

# ========= global --help =========
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# ========= commands =========
cmd="${1:-help}"; shift || true
case "$cmd" in
  help|-h|--help)
    usage
    exit 0
    ;;

  install)
    # Semantics:
    #   - install        => ConfigMaps only
    #   - install job    => Job prerequisites only
    #   - install cron   => Cron resources only
    #   - install all    => ConfigMaps + Job prerequisites + Cron resources
    mode="${1:-cm}"
    if [[ "$mode" == "-h" || "$mode" == "--help" ]]; then
      usage
      exit 0
    fi

    case "$mode" in
      cm)
        apply_configmaps
        echo "ConfigMaps installed."
        ;;

      job)
        apply_job_prereqs
        echo "Job prerequisites installed. (No ConfigMaps, no Cron.)"
        ;;

      cron)
        apply_cron
        echo "Cron resources installed. (No ConfigMaps, no Job prerequisites.)"
        ;;

      all)
        apply_configmaps
        apply_job_prereqs
        apply_cron
        echo "All installed: ConfigMaps + Job prerequisites + Cron resources."
        ;;

      *)
        echo "ERROR: install mode must be job|cron|all (or omit for cm)"
        echo
        usage
        exit 1
        ;;
    esac
    ;;

  uninstall)
    echo "Delete Cron resources (if any)..."
    kdelete "$CRON_YAML" || true
    kubectl -n "$NS" delete cronjob "$CRON_NAME" --ignore-not-found || true

    echo "Delete Jobs (label app=${JOB_APP_LABEL})..."
    kubectl -n "$NS" delete job -l "app=${JOB_APP_LABEL}" --ignore-not-found || true

    echo "Delete Jobs by prefix (CronJob children): ${CRON_NAME}-"
    delete_jobs_by_prefix "${CRON_NAME}-" || true

    echo "Delete Jobs by prefix (helper job run): ${JOB_APP_LABEL}-job-"
    delete_jobs_by_prefix "${JOB_APP_LABEL}-job-" || true

    echo "Delete Pods (label app=${JOB_APP_LABEL})..."
    kubectl -n "$NS" delete pod -l "app=${JOB_APP_LABEL}" --ignore-not-found || true

    echo "Delete Pods by prefix (CronJob children): ${CRON_NAME}-"
    delete_pods_by_prefix "${CRON_NAME}-" || true

    echo "Delete Pods by prefix (helper job run): ${JOB_APP_LABEL}-job-"
    delete_pods_by_prefix "${JOB_APP_LABEL}-job-" || true

    echo "Delete Job prerequisites (SA/CR/CRB...)..."
    extract_not_kind "$JOB_YAML" "Job" | kubectl delete -f - --ignore-not-found || true

    echo "Optionally stop running ChaosBlade (by env BLADE_NAME)..."
    stop_blade || true

    echo "Delete ConfigMaps..."
    kdelete "$SCRIPT_YAML" || true
    kdelete "$ENV_YAML" || true
    kdelete "$TEMPLATE_YAML" || true
    ;;

  cron)
    sub="${1:-}"; shift || true
    case "$sub" in
      ""|-h|--help|help)
        usage_cron
        exit 0
        ;;
      enable)  kapply "$CRON_YAML" ;;
      delete)  kdelete "$CRON_YAML" ;;
      suspend) kubectl -n "$NS" patch cronjob "$CRON_NAME" --type merge -p '{"spec":{"suspend":true}}' ;;
      resume)  kubectl -n "$NS" patch cronjob "$CRON_NAME" --type merge -p '{"spec":{"suspend":false}}' ;;
      schedule)
        expr="${1:-}"
        [[ -n "$expr" ]] || { echo "ERROR: cron schedule needs expr"; echo; usage_cron; exit 1; }
        kubectl -n "$NS" patch cronjob "$CRON_NAME" --type merge -p "{\"spec\":{\"schedule\":\"$expr\"}}"
        ;;
      set)
        [[ $# -ge 1 ]] || { echo "ERROR: cron set needs KEY=VALUE ..."; echo; usage_cron; exit 1; }
        cron_set "$@"
        ;;
      status)
        kubectl -n "$NS" get cronjob "$CRON_NAME" -o wide 2>/dev/null || true
        echo "--- recent jobs (label app=${JOB_APP_LABEL}) ---"
        kubectl -n "$NS" get jobs -l "app=${JOB_APP_LABEL}" --sort-by=.metadata.creationTimestamp -o wide 2>/dev/null \
          | tail -n 20 || true
        ;;
      *)
        echo "ERROR: cron subcmd: enable|delete|suspend|resume|schedule|set|status"
        echo
        usage_cron
        exit 1
        ;;
    esac
    ;;

  job)
    sub="${1:-}"; shift || true
    case "$sub" in
      ""|-h|--help|help)
        usage_job
        exit 0
        ;;
      run)
        echo "Apply Job prerequisites (SA/CR/CRB...)..."
        apply_job_prereqs
        echo "Create one Job run (generateName)..."
        jobres="$(extract_kind "$JOB_YAML" "Job" | kubectl create -f - -o name)"
        echo "Created: $jobres"
        ;;
      delete)
        jn="${1:-}"
        [[ -n "$jn" ]] || { echo "ERROR: job delete needs <jobName>"; echo; usage_job; exit 1; }
        kubectl -n "$NS" delete job "$jn" --ignore-not-found
        ;;
      status)
        kubectl -n "$NS" get jobs -l "app=${JOB_APP_LABEL}" --sort-by=.metadata.creationTimestamp -o wide 2>/dev/null || true
        ;;
      logs)
        which="${1:-last}"
        if [[ "$which" == "last" ]]; then
          jn="$(latest_job_name)"
          [[ -n "$jn" ]] || { echo "No jobs found with label app=${JOB_APP_LABEL}"; exit 1; }
        else
          jn="$which"
        fi
        echo "Job: $jn"
        kubectl -n "$NS" logs "job/$jn" -c runner --tail=200 || true
        ;;
      set)
        [[ $# -ge 1 ]] || { echo "ERROR: job set needs KEY=VALUE ..."; echo; usage_job; exit 1; }
        job_set "$@"
        ;;
      *)
        echo "ERROR: job subcmd: run|delete|status|logs|set"
        echo
        usage_job
        exit 1
        ;;
    esac
    ;;

  set)
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
      echo "Usage: $0 set KEY=VALUE [KEY=VALUE ...]"
      echo ""
      echo "Supported special parameters:"
      echo "  SELECTOR=<label-selector>        Automatically select a Pod via label selector (writes POD_NAME)"
      echo "  SELECTOR_MODE=newest|first|random Selection mode (default: newest)"
      exit 0
    fi
    [[ $# -ge 1 ]] || { echo "ERROR: set needs KEY=VALUE ..."; exit 1; }
    cm_set "$@"
    ;;

  select)
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
      echo "Usage: $0 select <label-selector> [namespace] [mode]"
      echo ""
      echo "Examples:"
      echo "  $0 select \"app=nginx\""
      echo "  $0 select \"app=nginx\" default"
      echo "  $0 select \"app=nginx\" default newest"
      exit 0
    fi
    [[ $# -ge 1 ]] || { echo "ERROR: select needs a label selector"; exit 1; }
    select_pod_by_label "$@"
    ;;

  show)
    echo "=== env configmap ($NS/$ENV_CM_NAME) ==="
    kubectl -n "$NS" get cm "$ENV_CM_NAME" -o yaml 2>/dev/null | sed -n '1,200p' || true
    echo
    echo "=== cronjob ($NS/$CRON_NAME) ==="
    kubectl -n "$NS" get cronjob "$CRON_NAME" -o wide 2>/dev/null || echo "(no cronjob)"
    echo
    echo "=== jobs (label app=$JOB_APP_LABEL) ==="
    kubectl -n "$NS" get jobs -l "app=${JOB_APP_LABEL}" --sort-by=.metadata.creationTimestamp -o wide 2>/dev/null || echo "(no jobs)"
    echo
    echo "=== chaosblades (try namespaced then cluster-scope) ==="
    kubectl -n "$NS" get chaosblades.chaosblade.io -o wide 2>/dev/null \
      || kubectl get chaosblades.chaosblade.io -o wide 2>/dev/null \
      || echo "(no chaosblades)"
    ;;

  stop)
    stop_blade
    ;;

  *)
    echo "ERROR: unknown cmd: $cmd"
    echo
    usage
    exit 1
    ;;
esac
