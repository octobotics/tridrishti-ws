#!/usr/bin/env bash
# Print the systemd service for this checkout. The installer uses this output.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
usage() {
  cat <<'EOF'
Usage: generate_robot_stack_service.sh

Print the systemd unit to stdout. The service runs as root. The workspace path
is embedded in the unit; regenerate after moving the workspace.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ "$WORKSPACE_DIR" =~ [[:space:]%] ]]; then
  echo "workspace path contains whitespace or %; systemd unit generation is unsupported: $WORKSPACE_DIR" >&2
  exit 2
fi
if [[ ! -x "$SCRIPT_DIR/launch_robot_stack.sh" ]]; then
  echo "robot launcher is not executable" >&2
  exit 2
fi

cat <<EOF
# Managed by generate_robot_stack_service.sh for $WORKSPACE_DIR
[Unit]
Description=TriDrishti robot stack
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=$WORKSPACE_DIR
EnvironmentFile=-/etc/default/tridrishti-robot-stack
ExecStart=$SCRIPT_DIR/launch_robot_stack.sh
Restart=on-failure
RestartSec=5s
KillMode=mixed
TimeoutStartSec=60s
TimeoutStopSec=60s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
