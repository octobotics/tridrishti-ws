#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${LOG_DIR:-${ROOT}/logs/local-fusion}"
I2W_ECAL_INSTALL_DIR="${I2W_ECAL_INSTALL_DIR:-${ROOT}/src/i2w/build/third_party/ecal-install}"

OUSTER_DIR="${OUSTER_DIR:-${ROOT}/src/ouster-lidar-pub}"
MIP_DIR="${MIP_DIR:-${ROOT}/src/mip-lidar-aiding-i2w}"
LOCAL_EKF_DIR="${LOCAL_EKF_DIR:-${ROOT}/src/local-ekf-i2w}"

OUSTER_BIN="${OUSTER_BIN:-${OUSTER_DIR}/build/ouster_lidar_i2w_pub}"
MIP_BIN="${MIP_BIN:-${MIP_DIR}/build/mip_lidar_aiding_i2w_node}"
LOCAL_EKF_BIN="${LOCAL_EKF_BIN:-${LOCAL_EKF_DIR}/build/local_ekf_i2w_node}"

OUSTER_CONFIG="${OUSTER_CONFIG:-${OUSTER_DIR}/config/config.json}"
MIP_CONFIG="${MIP_CONFIG:-${MIP_DIR}/config/config.json}"
LOCAL_EKF_CONFIG="${LOCAL_EKF_CONFIG:-${LOCAL_EKF_DIR}/config/config.json}"

STARTUP_DELAY_SEC="${STARTUP_DELAY_SEC:-2}"

pids=()
names=()

usage() {
  cat <<EOF
Usage: $(basename "$0")

Launches:
  ouster_lidar_i2w_pub
  mip_lidar_aiding_i2w_node
  local_ekf_i2w_node

Override paths with environment variables:
  OUSTER_CONFIG=/path/config.json
  MIP_CONFIG=/path/config.json
  LOCAL_EKF_CONFIG=/path/config.json

Build first if binaries are missing:
  (cd src/ouster-lidar-pub && ./scripts/build.sh)
  (cd src/mip-lidar-aiding-i2w && ./scripts/build.sh)
  (cd src/local-ekf-i2w && ./scripts/build.sh)
EOF
}

require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "${path}" ]]; then
    echo "missing ${label}: ${path}" >&2
    exit 1
  fi
}

require_executable() {
  local path="$1"
  local label="$2"
  if [[ ! -x "${path}" ]]; then
    echo "missing built binary for ${label}: ${path}" >&2
    echo "run that package's ./scripts/build.sh first" >&2
    exit 1
  fi
}

stop_all() {
  local status="${1:-0}"
  trap - INT TERM EXIT
  if [[ "${#pids[@]}" -gt 0 ]]; then
    echo "stopping local fusion stack..."
    for pid in "${pids[@]}"; do
      if kill -0 "${pid}" >/dev/null 2>&1; then
        kill "${pid}" >/dev/null 2>&1 || true
      fi
    done
    for pid in "${pids[@]}"; do
      wait "${pid}" >/dev/null 2>&1 || true
    done
  fi
  exit "${status}"
}

start_process() {
  local name="$1"
  local bin="$2"
  local config="$3"

  echo "starting ${name}"
  echo "  binary: ${bin}"
  echo "  config: ${config}"

  "${bin}" "${config}" &
  pids+=("$!")
  names+=("${name}")
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_executable "${OUSTER_BIN}" "ouster-lidar-pub"
require_executable "${MIP_BIN}" "mip-lidar-aiding-i2w"
require_executable "${LOCAL_EKF_BIN}" "local-ekf-i2w"
require_file "${OUSTER_CONFIG}" "Ouster config"
require_file "${MIP_CONFIG}" "MIP config"
require_file "${LOCAL_EKF_CONFIG}" "local EKF config"

if [[ -d "${I2W_ECAL_INSTALL_DIR}/bin" ]]; then
  export PATH="${I2W_ECAL_INSTALL_DIR}/bin:${PATH}"
fi

if [[ -d "${I2W_ECAL_INSTALL_DIR}/lib" ]]; then
  export LD_LIBRARY_PATH="${I2W_ECAL_INSTALL_DIR}/lib:${LD_LIBRARY_PATH:-}"
fi

trap 'stop_all 130' INT
trap 'stop_all 143' TERM
trap 'stop_all $?' EXIT

echo "launching local fusion stack"

start_process "ouster" "${OUSTER_BIN}" "${OUSTER_CONFIG}"
sleep "${STARTUP_DELAY_SEC}"

start_process "mip" "${MIP_BIN}" "${MIP_CONFIG}"
sleep "${STARTUP_DELAY_SEC}"

start_process "local_ekf" "${LOCAL_EKF_BIN}" "${LOCAL_EKF_CONFIG}"

echo
echo "local fusion stack running. Press Ctrl-C to stop."

while true; do
  for i in "${!pids[@]}"; do
    pid="${pids[$i]}"
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      echo "process exited: ${names[$i]} pid=${pid}" >&2
      stop_all 1
    fi
  done
  sleep 1
done
