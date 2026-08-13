#!/usr/bin/env bash
# ЛАБА 3.6 · Троттлинг ДОКАЗАТЕЛЬНО: cpu.stat вместо веры
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./oom_cpu_demo.yaml
kubectl -n traffic-lab rollout status deploy/night-shift-throttled --timeout=180s
CPU_POD=$(kubectl -n traffic-lab get pod -l app=night-shift-throttled -o jsonpath='{.items[0].metadata.name}')
CPU_IP=$(kubectl -n traffic-lab get pod "$CPU_POD" -o jsonpath='{.status.podIP}')
IMAGE=$(kubectl -n traffic-lab get deploy night-shift-throttled -o jsonpath='{.spec.template.spec.containers[0].image}')
NODE=$(kubectl -n traffic-lab get pod "$CPU_POD" -o jsonpath='{.spec.nodeName}')
BEFORE=$(kubectl get --raw "/api/v1/nodes/$NODE/proxy/metrics/cadvisor" | grep 'container_cpu_cfs_throttled_periods_total' | grep 'container="night-shift"' | grep "pod="$CPU_POD"" | awk '{print $2}' | head -1)
kubectl -n traffic-lab run overload-trigger --rm -i --restart=Never --image="$IMAGE"   --env="HEALTHCHECK_URL=http://$CPU_IP:8080/overload?sec=120" --command -- /night-shift -healthcheck
sleep 15
kubectl -n traffic-lab top pod "$CPU_POD"
AFTER=$(kubectl get --raw "/api/v1/nodes/$NODE/proxy/metrics/cadvisor" | grep 'container_cpu_cfs_throttled_periods_total' | grep 'container="night-shift"' | grep "pod="$CPU_POD"" | awk '{print $2}' | head -1)
printf 'throttled periods: before=%s after=%s
' "$BEFORE" "$AFTER"
kubectl -n traffic-lab get pod "$CPU_POD" -o jsonpath='{.status.containerStatuses[0].restartCount}{" restarts
"}'
# CPU limit замедляет процесс, но не убивает его: counter растёт, restarts=0.
kubectl -n traffic-lab delete deploy night-shift-throttled
