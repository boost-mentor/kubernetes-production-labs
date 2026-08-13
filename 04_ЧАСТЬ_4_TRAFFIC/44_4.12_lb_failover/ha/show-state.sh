#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

ansible load_balancers -i inventory.ini -b -a "systemctl is-active haproxy keepalived"
ansible load_balancers -i inventory.ini -b -a "ip -4 addr show dev vxlan100"
ansible lb1 -i inventory.ini -b -m uri -a "url=http://10.77.0.10:8080/ status_code=200"
