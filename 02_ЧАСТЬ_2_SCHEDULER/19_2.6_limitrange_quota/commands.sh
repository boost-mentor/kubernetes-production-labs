#!/usr/bin/env bash
# ЛАБА 2.6 · LimitRange + ResourceQuota: кусок кластера для команды
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/19_2.6_limitrange_quota"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

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
