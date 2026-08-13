#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ -f .failed-active-host ]]; then
  failed_host=$(<.failed-active-host)
  ansible "$failed_host" -i inventory.ini -b -a "systemctl start haproxy"
else
  ansible load_balancers -i inventory.ini -b -a "systemctl start haproxy"
fi
sleep 3
ansible load_balancers -i inventory.ini -b -a "systemctl is-active haproxy keepalived"
ansible lb1 -i inventory.ini -b -m uri -a "url=http://10.77.0.10:8080/ status_code=200"
rm -f .failed-active-host
echo "RESTORE OK"
