#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
INV="$ROOT_DIR/inventory/video2/inventory.ini"
ANSIBLE="$ROOT_DIR/.venv/bin/ansible"

[[ -x "$ANSIBLE" ]] || { echo "ERROR: run ./bootstrap.sh" >&2; exit 1; }
[[ -f "$INV" ]] || { echo "ERROR: run ./prepare-inventory.sh" >&2; exit 1; }

"$ANSIBLE" -i "$INV" all -m ping
"$ANSIBLE" -i "$INV" all -b -m shell -a \
  'test "$(swapon --show --noheadings | wc -l)" -eq 0; test "$(stat -fc %T /sys/fs/cgroup)" = cgroup2fs; ip -4 route show default'

echo "READY: SSH, sudo, swap=off, cgroup v2 and default routes"
