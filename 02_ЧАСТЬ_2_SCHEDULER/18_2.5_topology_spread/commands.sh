#!/usr/bin/env bash
# ЛАБА 2.5 · DevOps May Cry topology spread: измеряем перекос
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/18_2.5_topology_spread"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl -n traffic-lab patch deploy devops-may-cry --type merge   --patch-file ./hard-spread-patch.yaml
kubectl -n traffic-lab scale deploy devops-may-cry --replicas=4
kubectl -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl -n traffic-lab get pod -l app=devops-may-cry   -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.spec.nodeName
# На двух workers: 2+2.

kubectl -n traffic-lab scale deploy devops-may-cry --replicas=5
kubectl -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl -n traffic-lab get pod -l app=devops-may-cry   -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.spec.nodeName
# 3+2: maxSkew=1 соблюдён.

kubectl -n traffic-lab patch deploy devops-may-cry --type=json   -p='[{"op":"replace","path":"/spec/template/spec/topologySpreadConstraints/0/whenUnsatisfiable","value":"ScheduleAnyway"}]'
kubectl -n traffic-lab scale deploy devops-may-cry --replicas=2
kubectl -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
