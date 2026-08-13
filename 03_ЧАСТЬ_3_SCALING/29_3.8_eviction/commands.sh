#!/usr/bin/env bash
# ЛАБА 3.8 · Evicted-поиск: OOMKill ≠ Eviction
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/29_3.8_eviction"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl describe node node2 | grep -A6 Conditions
# → MemoryPressure / DiskPressure — сигналы kubelet о давлении
kubectl get pods -A --field-selector status.phase=Failed | grep -i evict
# → поды со Status: Failed, Reason: Evicted
kubectl get events --sort-by=.lastTimestamp | grep -iE 'evict|oom|pressure'


kubectl delete pod hog --ignore-not-found
kubectl delete -f ./requests_limits.yaml --ignore-not-found
kubectl delete pod --field-selector status.phase=Failed --ignore-not-found   # прибрать трупы Evicted
