#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
work_file=$(mktemp "${TMPDIR:-/tmp}/video2-metallb.XXXXXX.yaml")
trap 'rm -f "$work_file"' EXIT

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <pool-start> <pool-end>" >&2
  exit 2
fi

pool_start=$1
pool_end=$2
python3 - "$pool_start" "$pool_end" <<'PY'
import ipaddress
import sys

start = ipaddress.ip_address(sys.argv[1])
end = ipaddress.ip_address(sys.argv[2])
if start.version != 4 or end.version != 4 or int(start) > int(end):
    raise SystemExit("invalid IPv4 MetalLB range")
PY

helm repo add metallb https://metallb.github.io/metallb >/dev/null 2>&1 || true
helm repo update metallb
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace \
  --version 0.16.1 \
  --wait --timeout 5m

sed \
  -e "s/__POOL_START__/$pool_start/g" \
  -e "s/__POOL_END__/$pool_end/g" \
  "$script_dir/metallb-demo.yaml" > "$work_file"

echo "MetalLB explicit reserved pool: $pool_start-$pool_end"
kubectl apply -f "$work_file"

for attempt in {1..30}; do
  external_ip=$(kubectl -n traffic-lab get svc devops-may-cry-metallb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [[ -n "$external_ip" ]] && break
  sleep 2
done

test -n "${external_ip:-}" || { kubectl -n traffic-lab describe svc devops-may-cry-metallb; exit 1; }
kubectl -n metallb-system get pods
kubectl -n metallb-system get ipaddresspool,l2advertisement
kubectl -n traffic-lab get deploy,pod,svc,endpointslice -o wide
echo "METALLB DEMO OK: Service LoadBalancer получил EXTERNAL-IP=$external_ip"
