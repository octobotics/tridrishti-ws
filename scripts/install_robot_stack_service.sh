#!/usr/bin/env bash
# Install and enable the robot stack at boot. Does not start it unless asked.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UNIT_NAME="tridrishti-robot-stack.service"
UNIT_PATH="/etc/systemd/system/$UNIT_NAME"
START_NOW=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: install_robot_stack_service.sh [--start] [--dry-run]

Install and enable the service for boot. --start also starts it immediately.
Use sudo for installation; --dry-run only prints the generated unit.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start)
      START_NOW=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  exec "$SCRIPT_DIR/generate_robot_stack_service.sh"
fi
if [[ "$EUID" -ne 0 ]]; then
  echo "installation requires root; run: sudo $0" >&2
  exit 1
fi
if [[ -e "$UNIT_PATH" ]] && ! grep -Fq '# Managed by generate_robot_stack_service.sh' "$UNIT_PATH"; then
  echo "refusing to replace an unmanaged service: $UNIT_PATH" >&2
  exit 1
fi

unit_file="$(mktemp --suffix=.service)"
trap 'rm -f -- "$unit_file"' EXIT
"$SCRIPT_DIR/generate_robot_stack_service.sh" > "$unit_file"
if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze verify "$unit_file"
fi
install -m 0644 "$unit_file" "$UNIT_PATH"
systemctl daemon-reload
systemctl enable "$UNIT_NAME"
if [[ "$START_NOW" -eq 1 ]]; then
  systemctl restart "$UNIT_NAME"
fi
echo "installed and enabled $UNIT_NAME (runs as root)"
if [[ "$START_NOW" -eq 0 ]]; then
  echo "start now with: sudo systemctl start $UNIT_NAME"
fi
