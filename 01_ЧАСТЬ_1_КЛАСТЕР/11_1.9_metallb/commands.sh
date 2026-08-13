#!/usr/bin/env bash
# ЛАБА 1.9 · MetalLB чинит вечный `<pending>`
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl --context kubespray apply -k ./night-shift-base
kubectl --context kubespray -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl --context kubespray apply -f ./night-shift-loadbalancer.yaml
kubectl --context kubespray -n traffic-lab get svc night-shift-metallb
# До MetalLB это честный <pending>.

read -r -p "node subnet CIDR (example 10.10.0.0/24): " NODE_SUBNET_CIDR
read -r -p "reserved MetalLB pool start: " METALLB_POOL_START
read -r -p "reserved MetalLB pool end: " METALLB_POOL_END
# Подтверди только после проверки IPAM/DHCP/cloud source of truth.
export METALLB_POOL_RESERVED=yes
./preflight.sh "$NODE_SUBNET_CIDR" "$METALLB_POOL_START" "$METALLB_POOL_END"
./install-and-demo.sh "$METALLB_POOL_START" "$METALLB_POOL_END"
kubectl --context kubespray -n traffic-lab get svc night-shift-metallb -o wide
kubectl --context kubespray -n metallb-system logs -l component=speaker --tail=40
sed -n '1,220p' ./metallb-bgp-reference.yaml
# BGP reference не применяем: без настоящего router peer это был бы театр.
