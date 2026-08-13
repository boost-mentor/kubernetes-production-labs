#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

active=''
for host in lb1 lb2; do
  if ansible "$host" -i inventory.ini -b -a "ip -4 addr show dev vxlan100" | grep -q '10.77.0.10/24'; then
    active=$host
    break
  fi
done
test -n "$active" || { echo "VIP 10.77.0.10 не найден" >&2; exit 1; }

echo "ACTIVE before failure: $active"
ansible "$active" -i inventory.ini -b -a "systemctl stop haproxy"

new_active=''
for attempt in {1..20}; do
  for host in lb1 lb2; do
    if [[ "$host" != "$active" ]] && \
      ansible "$host" -i inventory.ini -b -a "ip -4 addr show dev vxlan100" | grep -q '10.77.0.10/24'; then
      new_active=$host
      break
    fi
  done
  if [[ -n "$new_active" ]] && \
    ansible lb1 -i inventory.ini -b -m uri -a "url=http://10.77.0.10:8080/ status_code=200" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

test -n "$new_active" || { echo "VIP не переехал с $active на второй LB" >&2; exit 1; }

ansible load_balancers -i inventory.ini -b -a "ip -4 addr show dev vxlan100"
ansible lb1 -i inventory.ini -b -m uri -a "url=http://10.77.0.10:8080/ status_code=200"
echo "$active" > .failed-active-host
echo "ACTIVE after failure: $new_active"
echo "FAILOVER OK: VIP переехал с $active на $new_active, HTTP восстановлен. Затем ./restore-after-demo.sh"
