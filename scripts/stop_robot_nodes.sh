#!/usr/bin/env bash
# Stop nodes declared in src_repos.sh.
#
# The launcher starts each node in its own session with setsid.  This script
# identifies a node by its exact executable path before signalling it, so it
# never relies on a broad process-name match such as `pkill mission`.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${WORKSPACE_DIR}/src"
REPO_LIST="${SCRIPT_DIR}/src_repos.sh"

source "${REPO_LIST}"

dry_run=0
selected_nodes=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] NODE [NODE ...]

Gracefully stops one or more launched robot nodes declared in:
  ${REPO_LIST}

NODE may be a launch name or repository name. Use 'all' to stop every
launchable node. A node is matched only when /proc/<pid>/exe equals its
configured binary path.

Options:
  -n, --dry-run    Print matching processes without signalling them.
  -h, --help       Show this help.

Examples:
  ./scripts/stop_robot_nodes.sh mission_planner
  ./scripts/stop_robot_nodes.sh local-ekf-i2w attitude_correction
  ./scripts/stop_robot_nodes.sh all
EOF
}

canonical_path() {
  local path="$1"
  readlink -f -- "${path}" 2>/dev/null || printf '%s\n' "${path}"
}

is_launch_node() {
  local wanted="$1"
  local entry repo _url _build_mode launch_name _binary_rel _config_rel _grace
  for entry in "${SRC_REPOS[@]}"; do
    IFS='|' read -r repo _url _build_mode launch_name _binary_rel _config_rel _grace <<<"${entry}"
    if [[ -n "${launch_name}" && ( "${wanted}" == "${launch_name}" || "${wanted}" == "${repo}" ) ]]; then
      return 0
    fi
  done
  return 1
}

append_node_once() {
  local node="$1"
  local existing
  for existing in "${selected_nodes[@]:-}"; do
    [[ "${existing}" == "${node}" ]] && return 0
  done
  selected_nodes+=("${node}")
}

add_target() {
  local wanted="$1"
  local entry repo _url _build_mode launch_name _binary_rel _config_rel _grace

  if [[ "${wanted}" == "all" ]]; then
    for entry in "${SRC_REPOS[@]}"; do
      IFS='|' read -r repo _url _build_mode launch_name _binary_rel _config_rel _grace <<<"${entry}"
      [[ -n "${launch_name}" ]] && append_node_once "${launch_name}"
    done
    return 0
  fi

  if ! is_launch_node "${wanted}"; then
    echo "unknown launchable node or repo: ${wanted}" >&2
    return 1
  fi

  for entry in "${SRC_REPOS[@]}"; do
    IFS='|' read -r repo _url _build_mode launch_name _binary_rel _config_rel _grace <<<"${entry}"
    if [[ -n "${launch_name}" && ( "${wanted}" == "${launch_name}" || "${wanted}" == "${repo}" ) ]]; then
      append_node_once "${launch_name}"
      return 0
    fi
  done
}

node_metadata() {
  local wanted="$1"
  local entry repo _url _build_mode launch_name binary_rel _config_rel grace
  for entry in "${SRC_REPOS[@]}"; do
    IFS='|' read -r repo _url _build_mode launch_name binary_rel _config_rel grace <<<"${entry}"
    if [[ "${launch_name}" == "${wanted}" ]]; then
      printf '%s|%s|%s\n' "${repo}" "$(canonical_path "${SRC_DIR}/${repo}/${binary_rel}")" "${grace:-0}"
      return 0
    fi
  done
  return 1
}

pid_matches_executable() {
  local pid="$1"
  local expected_exe="$2"
  local actual_exe
  [[ -r "/proc/${pid}/exe" ]] || return 1
  actual_exe="$(readlink -f -- "/proc/${pid}/exe" 2>/dev/null || true)"
  [[ -n "${actual_exe}" && "${actual_exe}" == "${expected_exe}" ]]
}

find_matching_pids() {
  local expected_exe="$1"
  local proc_dir pid
  for proc_dir in /proc/[0-9]*; do
    pid="${proc_dir##*/}"
    pid_matches_executable "${pid}" "${expected_exe}" && printf '%s\n' "${pid}"
  done
}

signal_node_process() {
  local pid="$1"
  local signal="$2"
  local pgid
  pgid="$(ps -o pgid= -p "${pid}" 2>/dev/null | tr -d '[:space:]')"
  # A stack-launched node is its own session/process-group leader. Signal its
  # entire group so any node-owned helper is stopped as well. For manually
  # launched nodes, signal only the verified executable PID.
  if [[ "${pgid}" == "${pid}" ]]; then
    kill -"${signal}" -- "-${pid}"
  else
    kill -"${signal}" -- "${pid}"
  fi
}

wait_for_exit() {
  local pid="$1"
  local expected_exe="$2"
  local wait_seconds="$3"
  local elapsed=0
  local interval_ms=100
  local maximum_ms=$((wait_seconds * 1000))

  while pid_matches_executable "${pid}" "${expected_exe}"; do
    if (( elapsed >= maximum_ms )); then
      return 1
    fi
    sleep 0.1
    elapsed=$((elapsed + interval_ms))
  done
  return 0
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -n|--dry-run)
      dry_run=1
      shift
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      add_target "$1"
      shift
      ;;
  esac
done

if [[ "${#selected_nodes[@]}" -eq 0 ]]; then
  usage >&2
  exit 2
fi

for node in "${selected_nodes[@]}"; do
  IFS='|' read -r repo expected_exe grace < <(node_metadata "${node}")
  mapfile -t pids < <(find_matching_pids "${expected_exe}")

  if [[ "${#pids[@]}" -eq 0 ]]; then
    echo "${node}: not running (${expected_exe})"
    continue
  fi

  for pid in "${pids[@]}"; do
    if [[ "${dry_run}" -eq 1 ]]; then
      echo "${node}: would stop pid=${pid} executable=${expected_exe}"
      continue
    fi

    echo "${node}: stopping pid=${pid} (SIGTERM, grace=${grace}s)"
    signal_node_process "${pid}" TERM || {
      echo "${node}: could not signal pid=${pid}" >&2
      continue
    }

    if wait_for_exit "${pid}" "${expected_exe}" "${grace}"; then
      echo "${node}: stopped"
      continue
    fi

    if pid_matches_executable "${pid}" "${expected_exe}"; then
      echo "${node}: still running; forcing pid=${pid} (SIGKILL)" >&2
      signal_node_process "${pid}" KILL || echo "${node}: could not force-stop pid=${pid}" >&2
    fi
  done
done
