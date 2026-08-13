#!/usr/bin/env bash
# ЛАБА 3.5 · OOMKilled: exit code 137 = 128 + 9
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./oom_cpu_demo.yaml
kubectl -n traffic-lab rollout status deploy/night-shift-oom --timeout=180s
OOM_POD=$(kubectl -n traffic-lab get pod -l app=night-shift-oom -o jsonpath='{.items[0].metadata.name}')
OOM_IP=$(kubectl -n traffic-lab get pod "$OOM_POD" -o jsonpath='{.status.podIP}')
IMAGE=$(kubectl -n traffic-lab get deploy night-shift-oom -o jsonpath='{.spec.template.spec.containers[0].image}')
kubectl -n traffic-lab run wound-trigger --rm -i --restart=Never --image="$IMAGE"   --env="HEALTHCHECK_URL=http://$OOM_IP:8080/wound?mb=160" --command -- /night-shift -healthcheck || true
kubectl -n traffic-lab get pod "$OOM_POD" -w
# Ctrl+C после появления RESTARTS, затем доказательство:
kubectl -n traffic-lab describe pod "$OOM_POD" | sed -n '/Last State:/,/Ready:/p'
kubectl -n traffic-lab get pod "$OOM_POD" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{" exit="}{.status.containerStatuses[0].lastState.terminated.exitCode}{"
"}'

NODE=$(kubectl -n traffic-lab get pod "$OOM_POD" -o jsonpath='{.spec.nodeName}')
read -r -p "public/floating IP ноды $NODE: " NODE_SSH_HOST
ssh "root@$NODE_SSH_HOST" 'sudo dmesg -T | grep -iE "memory cgroup out of memory|killed process" | tail -5'
# Restore: убираем лабораторный OOM workload перед следующей сценой.
kubectl -n traffic-lab delete deploy night-shift-oom
