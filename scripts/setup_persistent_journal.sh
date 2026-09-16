#!/usr/bin/env bash
# Enable journal retention across unclean resets. Run once before robot testing.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

install -d -m 2755 /var/log/journal
install -d -m 0755 /etc/systemd/journald.conf.d
printf '%s\n' \
  '[Journal]' \
  'Storage=persistent' \
  'Compress=yes' \
  'SystemMaxUse=512M' \
  'RuntimeMaxUse=128M' \
  > /etc/systemd/journald.conf.d/robot-persistent.conf

systemctl restart systemd-journald
journalctl --flush

echo 'Persistent journal enabled (maximum on-disk size: 512 MiB).'
echo 'Verify with: journalctl --list-boots'
