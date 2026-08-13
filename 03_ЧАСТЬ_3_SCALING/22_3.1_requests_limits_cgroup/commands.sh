#!/usr/bin/env bash
# ЛАБА 3.1 · Два читателя одного манифеста: cgroup vs планировщик
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./requests_limits.yaml
kubectl -n traffic-lab rollout status deploy/night-shift-burstable --timeout=180s
POD=$(kubectl -n traffic-lab get pod -l app=night-shift-burstable -o jsonpath='{.items[0].metadata.name}')
NODE=$(kubectl -n traffic-lab get pod "$POD" -o jsonpath='{.spec.nodeName}')
kubectl -n traffic-lab get pod "$POD" -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass,REQUEST_CPU:.spec.containers[0].resources.requests.cpu,LIMIT_CPU:.spec.containers[0].resources.limits.cpu,REQUEST_MEM:.spec.containers[0].resources.requests.memory,LIMIT_MEM:.spec.containers[0].resources.limits.memory'
kubectl describe node "$NODE" | sed -n '/Allocated resources:/,/Events:/p'

# Production image distroless: shell/cat внутри намеренно нет.
kubectl -n traffic-lab exec "$POD" -- cat /sys/fs/cgroup/memory.max || true
CONTAINER_ID=$(kubectl -n traffic-lab get pod "$POD" -o jsonpath='{.status.containerStatuses[0].containerID}' | sed 's#^[^:]*://##')
read -r -p "public/floating IP ноды $NODE: " NODE_SSH_HOST
ssh "root@$NODE_SSH_HOST" "PID=$(sudo crictl inspect '$CONTAINER_ID' | sed -n 's/.*"pid": ([0-9][0-9]*).*//p' | head -1); sudo nsenter -t "$PID" -m cat /sys/fs/cgroup/memory.max; sudo nsenter -t "$PID" -m cat /sys/fs/cgroup/cpu.max"
# Kernel читает limits из cgroup; scheduler суммирует requests на ноде.
