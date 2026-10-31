#!/usr/bin/env bash
# Stop, disable, and remove the managed robot stack service.
set -euo pipefail

UNIT_NAME="tridrishti-robot-stack.service"
UNIT_PATH="/etc/systemd/system/$UNIT_NAME"

if [[ $# -ne 0 ]]; then
  echo "Usage: uninstall_robot_stack_service.sh" >&2
  exit 2
fi
if [[ "$EUID" -ne 0 ]]; then
  echo "uninstallation requires root; run: sudo $0" >&2
  exit 1
fi
if [[ ! -e "$UNIT_PATH" ]]; then
  echo "$UNIT_NAME is not installed at $UNIT_PATH"
  exit 0
fi
if ! grep -Fq '# Managed by generate_robot_stack_service.sh' "$UNIT_PATH"; then
  echo "refusing to remove an unmanaged service: $UNIT_PATH" >&2
  exit 1
fi

systemctl disable --now "$UNIT_NAME"
rm -f -- "$UNIT_PATH"
systemctl daemon-reload
echo "removed $UNIT_NAME"
