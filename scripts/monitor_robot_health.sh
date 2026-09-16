#!/usr/bin/env bash
# Capture host health around a robot run. Stop with Ctrl-C after the run.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
LOG_BASE_DIR="${LOG_BASE_DIR:-${ROOT}/logs/health}"
INTERVAL_SEC="${INTERVAL_SEC:-1}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)}"
LOG_DIR="${LOG_DIR:-${LOG_BASE_DIR}/${SESSION_ID}}"
PIDS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [--interval SECONDS] [--log-dir DIRECTORY]

Writes tegrastats, all readable thermal zones, readable power/voltage/current
sysfs inputs, and a live kernel journal to ${LOG_DIR}.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval) INTERVAL_SEC="$2"; shift 2 ;;
    --log-dir) LOG_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! [[ ${INTERVAL_SEC} =~ ^[1-9][0-9]*$ ]]; then
  echo '--interval must be a positive whole number of seconds' >&2
  exit 2
fi

mkdir -p "${LOG_DIR}"
date --iso-8601=seconds > "${LOG_DIR}/started_at.txt"
uname -a > "${LOG_DIR}/uname.txt"
printf 'interval_sec=%s\n' "${INTERVAL_SEC}" > "${LOG_DIR}/session.env"

stop() {
  trap - EXIT INT TERM
  for pid in "${PIDS[@]:-}"; do kill "${pid}" 2>/dev/null || true; done
  wait 2>/dev/null || true
  date --iso-8601=seconds > "${LOG_DIR}/stopped_at.txt"
  echo "Health logs saved in ${LOG_DIR}"
}
trap stop EXIT INT TERM

sample_thermal() {
  while true; do
    {
      printf '%s' "$(date --iso-8601=seconds)"
      for zone in /sys/class/thermal/thermal_zone*; do
        [[ -r "${zone}/temp" && -r "${zone}/type" ]] || continue
        type="$(cat "${zone}/type" 2>/dev/null || true)"
        millideg_c="$(cat "${zone}/temp" 2>/dev/null || true)"
        [[ ${millideg_c} =~ ^-?[0-9]+$ ]] || continue
        printf ' %s_c=%.3f' "${type}" "$((millideg_c))e-3"
      done
      printf '\n'
    } >> "${LOG_DIR}/thermal.log"
    sleep "${INTERVAL_SEC}"
  done
}

sample_power() {
  while true; do
    {
      printf '%s' "$(date --iso-8601=seconds)"
      for sensor in /sys/class/hwmon/hwmon*/in*_input /sys/class/hwmon/hwmon*/curr*_input /sys/class/hwmon/hwmon*/power*_input /sys/bus/iio/devices/iio:device*/in_voltage*_raw /sys/bus/iio/devices/iio:device*/in_current*_raw; do
        [[ -r "${sensor}" ]] || continue
        value="$(cat "${sensor}" 2>/dev/null || true)"
        [[ -n ${value} ]] || continue
        printf ' %s=%s' "${sensor#/sys/}" "${value}"
      done
      printf '\n'
    } >> "${LOG_DIR}/power_voltage.log"
    sleep "${INTERVAL_SEC}"
  done
}

sample_thermal & PIDS+=("$!")
sample_power & PIDS+=("$!")
journalctl -kf -o short-iso > "${LOG_DIR}/kernel.log" 2>&1 & PIDS+=("$!")

if command -v tegrastats >/dev/null 2>&1; then
  tegrastats --interval "$(( INTERVAL_SEC * 1000 ))" --logfile "${LOG_DIR}/tegrastats.log" &
  PIDS+=("$!")
else
  echo 'tegrastats is unavailable on this host' > "${LOG_DIR}/tegrastats.log"
fi

echo "Monitoring robot health in ${LOG_DIR}"
wait
