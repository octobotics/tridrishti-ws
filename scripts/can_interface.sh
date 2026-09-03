#!/usr/bin/env bash
set -euo pipefail

CAN_IFACE="${CAN_IFACE:-can0}"
CAN_BITRATE="${CAN_BITRATE:-1000000}"
CAN_RESTART_MS="${CAN_RESTART_MS:-100}"

usage() {
  cat <<EOF
Usage: $(basename "$0") up|down|restart|status

Environment:
  CAN_IFACE=can0
  CAN_BITRATE=1000000
  CAN_RESTART_MS=100

Examples:
  ./scripts/can_interface.sh up
  ./scripts/can_interface.sh down
  CAN_IFACE=can1 CAN_BITRATE=1000000 ./scripts/can_interface.sh up
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

can_up() {
  sudo ip link set "${CAN_IFACE}" down 2>/dev/null || true
  sudo ip link set "${CAN_IFACE}" type can bitrate "${CAN_BITRATE}" restart-ms "${CAN_RESTART_MS}"
  sudo ip link set "${CAN_IFACE}" up
  ip -details -statistics link show "${CAN_IFACE}"
}

can_down() {
  sudo ip link set "${CAN_IFACE}" down
  ip -details -statistics link show "${CAN_IFACE}"
}

require_cmd ip

case "${1:-}" in
  up)
    can_up
    ;;
  down)
    can_down
    ;;
  restart)
    can_down
    can_up
    ;;
  status)
    ip -details -statistics link show "${CAN_IFACE}"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "unknown command: $1" >&2
    usage >&2
    exit 2
    ;;
esac
