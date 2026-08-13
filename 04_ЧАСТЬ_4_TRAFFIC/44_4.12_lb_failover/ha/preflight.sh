#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

test -f inventory.ini || { echo "Сначала ./prepare-inventory.sh ..." >&2; exit 2; }
ansible-inventory -i inventory.ini --graph
ansible -i inventory.ini all -m ping
ansible-playbook -i inventory.ini site.yml --syntax-check
ansible-playbook -i inventory.ini preflight-backends.yml
echo "PRE-FLIGHT OK: 5 VM доступны, 3 backend дают HTTP, Ansible syntax OK"
