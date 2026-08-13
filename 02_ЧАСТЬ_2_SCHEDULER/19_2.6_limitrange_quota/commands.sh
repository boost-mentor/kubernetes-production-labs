#!/usr/bin/env bash
# ЛАБА 2.6 · LimitRange + ResourceQuota: кусок кластера для команды
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl create ns team-dev
kubectl apply -f ./limitrange_resourcequota.yaml -n team-dev
kubectl run naked --image=nginx:1.27 -n team-dev     # под БЕЗ ресурсов — «голый»
kubectl get pod naked -n team-dev -o jsonpath='{.spec.containers[0].resources}'; echo
# → {"limits":{…},"requests":{…}}  ← LimitRange ПОДСТАВИЛ дефолты сам
kubectl describe quota -n team-dev
# → Resource  Used  Hard   ← «голый» под уже съел кусок квоты


kubectl run fat -n team-dev --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"fat","image":"nginx:1.27","resources":{"requests":{"cpu":"64"}}}]}}'
# → Error from server (Forbidden): … exceeded quota …


kubectl delete ns team-dev
