#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${ROOT}/src"
REPO_LIST="${SCRIPT_DIR}/src_repos.sh"

source "${REPO_LIST}"

LOG_BASE_DIR="${LOG_BASE_DIR:-${ROOT}/logs/robot}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)}"
LOG_DIR="${LOG_DIR:-${LOG_BASE_DIR}/${SESSION_ID}}"
I2W_ECAL_INSTALL_DIR="${I2W_ECAL_INSTALL_DIR:-${SRC_DIR}/i2w/build/third_party/ecal-install}"
STARTUP_DELAY_SEC="${STARTUP_DELAY_SEC:-2}"
HEALTH_MONITOR_SCRIPT="${HEALTH_MONITOR_SCRIPT:-${SCRIPT_DIR}/monitor_robot_health.sh}"
HEALTH_MONITOR="${HEALTH_MONITOR:-1}"
HEALTH_MONITOR_INTERVAL_SEC="${HEALTH_MONITOR_INTERVAL_SEC:-1}"
health_monitor_pid=""

pids=()
names=()
shutdown_graces=()
show_logs=()
launch_failures=()

bold_red() {
  printf '\033[1;31m%s\033[0m\n' "$*" >&2
}

env_prefix() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

env_or_default() {
  local var="$1"
  local default="$2"
  if [[ -v "${var}" ]]; then
    printf '%s' "${!var}"
  else
    printf '%s' "${default}"
  fi
}

launch_nodes_csv() {
  local entry _repo _url _build_mode launch_name _binary_rel _config_rel _shutdown_grace_sec
  local sep=""

  for entry in "${SRC_REPOS[@]}"; do
    IFS='|' read -r _repo _url _build_mode launch_name _binary_rel _config_rel _shutdown_grace_sec <<<"${entry}"
    if [[ -n "${launch_name}" ]]; then
      printf '%s%s' "${sep}" "${launch_name}"
      sep=", "
    fi
  done
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [--show-log NODE[,NODE...]] [--no-health-monitor]

Launches all launchable nodes listed in:
  ${REPO_LIST}

Logs are written to:
  ${LOG_DIR}

Mirror selected logs to this terminal:
  --show-log ouster
  --show-log mip,dwe
  --show-log all
  --no-health-monitor
  --health-monitor-interval SECONDS

Available node log names:
  $(launch_nodes_csv), all

Override paths with environment variables:
  LOG_BASE_DIR=/path/to/log/root
  SESSION_ID=custom-session-name
  LOG_DIR=/path/to/exact/session/log/dir
  <NODE>_DIR=/path/to/repo
  <NODE>_BIN=/path/to/binary
  <NODE>_CONFIG=/path/to/config.json

For example:
  OUSTER_CONFIG=/path/config.json ./scripts/launch_robot_stack.sh
  MYACTUATOR_CONFIG= ./scripts/launch_robot_stack.sh
  HEALTH_MONITOR=0 ./scripts/launch_robot_stack.sh

Build first if binaries are missing:
  ./scripts/build_src_repos.sh
EOF
}

is_launch_node() {
  local node="$1"
  local entry _repo _url _build_mode launch_name _binary_rel _config_rel _shutdown_grace_sec

  [[ "${node}" == "all" ]] && return 0

  for entry in "${SRC_REPOS[@]}"; do
    IFS='|' read -r _repo _url _build_mode launch_name _binary_rel _config_rel _shutdown_grace_sec <<<"${entry}"
    if [[ "${launch_name}" == "${node}" ]]; then
      return 0
    fi
  done

  return 1
}

add_show_logs() {
  local value="$1"
  local node
  IFS=',' read -ra requested_nodes <<<"${value}"
  for node in "${requested_nodes[@]}"; do
    if is_launch_node "${node}"; then
      show_logs+=("${node}")
    elif [[ -n "${node}" ]]; then
      echo "unknown node for --show-log: ${node}" >&2
      echo "valid names: $(launch_nodes_csv), all" >&2
      exit 2
    fi
  done
}

should_show_log() {
  local name="$1"
  local requested
  for requested in "${show_logs[@]}"; do
    if [[ "${requested}" == "all" || "${requested}" == "${name}" ]]; then
      return 0
    fi
  done
  return 1
}

stop_all() {
  local status="${1:-0}"
  local i pid name grace
  trap - INT TERM EXIT
  if [[ -n "${health_monitor_pid}" ]]; then
    kill "${health_monitor_pid}" >/dev/null 2>&1 || true
    wait "${health_monitor_pid}" >/dev/null 2>&1 || true
  fi
  if [[ "${#pids[@]}" -gt 0 ]]; then
    echo "stopping robot stack..."
    echo "shutdown order:"
    for i in "${!pids[@]}"; do
      pid="${pids[$i]}"
      name="${names[$i]:-node}"
      grace="${shutdown_graces[$i]:-0}"
      if [[ -z "${pid}" ]]; then
        echo "  ${name}: already exited, grace=${grace}s"
      elif kill -0 "${pid}" >/dev/null 2>&1; then
        echo "  ${name}: pid=${pid}, grace=${grace}s"
      else
        echo "  ${name}: already exited pid=${pid}, grace=${grace}s"
      fi
    done
    for i in "${!pids[@]}"; do
      pid="${pids[$i]}"
      name="${names[$i]:-node}"
      grace="${shutdown_graces[$i]:-0}"
      if [[ -z "${pid}" ]]; then
        continue
      fi
      if kill -0 "${pid}" >/dev/null 2>&1; then
        echo "kill ${name} pid=${pid}"
        kill -- "-${pid}" >/dev/null 2>&1 || kill "${pid}" >/dev/null 2>&1 || true
        echo "wait ${grace}s after ${name}"
        if [[ "${grace}" != "0" ]]; then
          sleep "${grace}"
        fi
      else
        echo "skip ${name} pid=${pid} already exited"
        echo "wait ${grace}s after ${name}"
        if [[ "${grace}" != "0" ]]; then
          sleep "${grace}"
        fi
      fi
    done
    for pid in "${pids[@]}"; do
      if [[ -z "${pid}" ]]; then
        continue
      fi
      wait "${pid}" >/dev/null 2>&1 || true
    done
  fi
  exit "${status}"
}

start_health_monitor() {
  if [[ "${HEALTH_MONITOR}" != "1" ]]; then
    echo "health monitor disabled"
    return 0
  fi
  if [[ ! -x "${HEALTH_MONITOR_SCRIPT}" ]]; then
    bold_red "WARNING: health monitor not started: missing executable ${HEALTH_MONITOR_SCRIPT}"
    return 0
  fi
  echo "starting health monitor (interval: ${HEALTH_MONITOR_INTERVAL_SEC}s)"
  mkdir -p "${LOG_DIR}/health"
  LOG_DIR="${LOG_DIR}/health" INTERVAL_SEC="${HEALTH_MONITOR_INTERVAL_SEC}" \
    "${HEALTH_MONITOR_SCRIPT}" > "${LOG_DIR}/health_monitor.log" 2>&1 &
  health_monitor_pid="$!"
}

check_persistent_journal() {
  if [[ ! -d /var/log/journal ]]; then
    bold_red "WARNING: persistent journal is not enabled; run: sudo ${SCRIPT_DIR}/setup_persistent_journal.sh"
  fi
}

start_process() {
  local name="$1"
  local workdir="$2"
  local bin="$3"
  local config="$4"
  local shutdown_grace_sec="${5:-0}"
  local log_file="${LOG_DIR}/${name}.log"

  if [[ ! -d "${workdir}" ]]; then
    bold_red "ERROR: ${name} not launched: missing directory ${workdir}"
    launch_failures+=("${name}")
    return 0
  fi

  if [[ ! -x "${bin}" ]]; then
    bold_red "ERROR: ${name} not launched: missing executable ${bin}"
    launch_failures+=("${name}")
    return 0
  fi

  if [[ -n "${config}" && ! -f "${config}" ]]; then
    bold_red "ERROR: ${name} not launched: missing config ${config}"
    launch_failures+=("${name}")
    return 0
  fi

  echo "starting ${name}"
  echo "  binary: ${bin}"
  if [[ -n "${config}" ]]; then
    echo "  config: ${config}"
  else
    echo "  config: <built-in defaults>"
  fi
  echo "  log:    ${log_file}"

  : >"${log_file}"

  if should_show_log "${name}"; then
    (
      trap '' INT
      cd "${workdir}"
      if [[ -n "${config}" ]]; then
        exec setsid "${bin}" "${config}"
      else
        exec setsid "${bin}"
      fi
    ) > >(tee -a "${log_file}" | sed "s/^/[${name}] /") 2>&1 &
  else
    (
      trap '' INT
      cd "${workdir}"
      if [[ -n "${config}" ]]; then
        exec setsid "${bin}" "${config}"
      else
        exec setsid "${bin}"
      fi
    ) >"${log_file}" 2>&1 &
  fi

  pids+=("$!")
  names+=("${name}")
  shutdown_graces+=("${shutdown_grace_sec}")
}

write_session_env() {
  local entry repo _url _build_mode launch_name binary_rel config_rel shutdown_grace_sec
  local prefix dir_var bin_var config_var dir bin config

  {
    echo "session_id=${SESSION_ID}"
    echo "started_at=$(date --iso-8601=seconds)"
    echo "root=${ROOT}"
    for entry in "${SRC_REPOS[@]}"; do
      IFS='|' read -r repo _url _build_mode launch_name binary_rel config_rel shutdown_grace_sec <<<"${entry}"
      if [[ -z "${launch_name}" ]]; then
        continue
      fi

      prefix="$(env_prefix "${launch_name}")"
      dir_var="${prefix}_DIR"
      bin_var="${prefix}_BIN"
      config_var="${prefix}_CONFIG"
      dir="$(env_or_default "${dir_var}" "${SRC_DIR}/${repo}")"
      bin="$(env_or_default "${bin_var}" "${dir}/${binary_rel}")"
      if [[ -n "${config_rel}" ]]; then
        config="$(env_or_default "${config_var}" "${dir}/${config_rel}")"
      else
        config="$(env_or_default "${config_var}" "")"
      fi

      echo "${launch_name}_bin=${bin}"
      echo "${launch_name}_config=${config}"
      echo "${launch_name}_shutdown_grace_sec=${shutdown_grace_sec:-0}"
    done
    echo "show_logs=${show_logs[*]:-}"
    echo "health_monitor=${HEALTH_MONITOR}"
    echo "health_monitor_interval_sec=${HEALTH_MONITOR_INTERVAL_SEC}"
  } >"${LOG_DIR}/session.env"
}

launch_all_nodes() {
  local entry repo _url _build_mode launch_name binary_rel config_rel shutdown_grace_sec
  local prefix dir_var bin_var config_var dir bin config

  for entry in "${SRC_REPOS[@]}"; do
    IFS='|' read -r repo _url _build_mode launch_name binary_rel config_rel shutdown_grace_sec <<<"${entry}"
    if [[ -z "${launch_name}" ]]; then
      continue
    fi

    prefix="$(env_prefix "${launch_name}")"
    dir_var="${prefix}_DIR"
    bin_var="${prefix}_BIN"
    config_var="${prefix}_CONFIG"
    dir="$(env_or_default "${dir_var}" "${SRC_DIR}/${repo}")"
    bin="$(env_or_default "${bin_var}" "${dir}/${binary_rel}")"
    if [[ -n "${config_rel}" ]]; then
      config="$(env_or_default "${config_var}" "${dir}/${config_rel}")"
    else
      config="$(env_or_default "${config_var}" "")"
    fi

    start_process "${launch_name}" "${dir}" "${bin}" "${config}" "${shutdown_grace_sec:-0}"
    sleep "${STARTUP_DELAY_SEC}"
  done
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --show-log|--show-logs)
      if [[ -z "${2:-}" ]]; then
        echo "$1 requires a node name, comma-separated names, or all" >&2
        exit 2
      fi
      add_show_logs "$2"
      shift 2
      ;;
    --show-log=*|--show-logs=*)
      add_show_logs "${1#*=}"
      shift
      ;;
    --no-health-monitor)
      HEALTH_MONITOR=0
      shift
      ;;
    --health-monitor-interval)
      if [[ -z "${2:-}" ]]; then
        echo "$1 requires a positive whole number of seconds" >&2
        exit 2
      fi
      HEALTH_MONITOR_INTERVAL_SEC="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "${LOG_DIR}"
write_session_env

if [[ -d "${I2W_ECAL_INSTALL_DIR}/bin" ]]; then
  export PATH="${I2W_ECAL_INSTALL_DIR}/bin:${PATH}"
fi

if [[ -d "${I2W_ECAL_INSTALL_DIR}/lib" ]]; then
  export LD_LIBRARY_PATH="${I2W_ECAL_INSTALL_DIR}/lib:${LD_LIBRARY_PATH:-}"
fi

trap 'stop_all 130' INT
trap 'stop_all 143' TERM
trap 'stop_all $?' EXIT

echo "launching robot stack"
echo "session: ${SESSION_ID}"
echo "logs: ${LOG_DIR}"
if [[ "${#show_logs[@]}" -gt 0 ]]; then
  echo "mirroring logs: ${show_logs[*]}"
fi
check_persistent_journal
start_health_monitor

launch_all_nodes

echo
if [[ "${#launch_failures[@]}" -gt 0 ]]; then
  bold_red "nodes not launched: ${launch_failures[*]}"
fi

if [[ "${#pids[@]}" -eq 0 ]]; then
  bold_red "no nodes launched successfully"
  exit 1
fi

echo "robot stack running. Press Ctrl-C to stop."

while true; do
  active_count=0
  for i in "${!pids[@]}"; do
    pid="${pids[$i]}"
    if [[ -z "${pid}" ]]; then
      continue
    fi
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      bold_red "process exited: ${names[$i]} pid=${pid}"
      wait "${pid}" >/dev/null 2>&1 || true
      pids[$i]=""
      continue
    fi
    active_count=$((active_count + 1))
  done

  if [[ "${active_count}" -eq 0 ]]; then
    bold_red "all launched nodes have exited"
    exit 1
  fi

  sleep 1
done
