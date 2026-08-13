#!/usr/bin/env bash
# ЛАБА 2.5 · Night Shift topology spread: измеряем перекос
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/18_2.5_topology_spread"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl -n traffic-lab patch deploy night-shift --type merge   --patch-file ./hard-spread-patch.yaml
kubectl -n traffic-lab scale deploy night-shift --replicas=4
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl -n traffic-lab get pod -l app=night-shift   -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.spec.nodeName
# На двух workers: 2+2.

kubectl -n traffic-lab scale deploy night-shift --replicas=5
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl -n traffic-lab get pod -l app=night-shift   -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.spec.nodeName
# 3+2: maxSkew=1 соблюдён.

kubectl -n traffic-lab patch deploy night-shift --type=json   -p='[{"op":"replace","path":"/spec/template/spec/topologySpreadConstraints/0/whenUnsatisfiable","value":"ScheduleAnyway"}]'
kubectl -n traffic-lab scale deploy night-shift --replicas=2
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
