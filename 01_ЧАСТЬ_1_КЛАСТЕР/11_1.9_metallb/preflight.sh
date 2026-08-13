#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <node-subnet-cidr> <pool-start> <pool-end>" >&2
  echo "example: $0 10.10.0.0/24 10.10.0.240 10.10.0.250" >&2
  exit 2
fi

subnet_cidr=$1
pool_start=$2
pool_end=$3

kubectl get nodes
test "$(kubectl get nodes --no-headers | awk '$2 == "Ready" {n++} END {print n+0}')" -eq 3
helm version --short
kubectl auth can-i create namespace | grep -q '^yes$'
kubectl -n kube-system get configmap kube-proxy -o yaml | grep -q 'strictARP: true'

node_ips=$(
  kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
)

NODE_IPS="$node_ips" python3 - "$subnet_cidr" "$pool_start" "$pool_end" <<'PY'
import ipaddress
import os
import sys

network = ipaddress.ip_network(sys.argv[1], strict=True)
start = ipaddress.ip_address(sys.argv[2])
end = ipaddress.ip_address(sys.argv[3])
nodes = [ipaddress.ip_address(value) for value in os.environ["NODE_IPS"].splitlines() if value]

if start.version != 4 or end.version != 4:
    raise SystemExit("MetalLB recording pool must use IPv4")
if start not in network or end not in network:
    raise SystemExit(f"pool {start}-{end} is outside node subnet {network}")
if int(start) > int(end):
    raise SystemExit("pool start is greater than pool end")
if start == network.network_address or end == network.broadcast_address:
    raise SystemExit("pool includes network/broadcast address")
overlap = [str(node) for node in nodes if int(start) <= int(node) <= int(end)]
if overlap:
    raise SystemExit("pool overlaps Kubernetes node IP: " + ", ".join(overlap))

print(f"validated pool: {start}-{end} inside {network}; node IP overlap: none")
PY

if [[ ${METALLB_POOL_RESERVED:-} != "yes" ]]; then
  echo >&2
  echo "P0: reserve $pool_start-$pool_end outside DHCP/cloud allocations first." >&2
  echo "An empty ping/ARP cache is not proof that an address is free." >&2
  echo "After checking the provider/network source of truth, run:" >&2
  echo "  export METALLB_POOL_RESERVED=yes" >&2
  exit 1
fi

echo "METALLB PRE-FLIGHT OK: 3 Ready, helm/права, strictARP, explicit reserved pool"
