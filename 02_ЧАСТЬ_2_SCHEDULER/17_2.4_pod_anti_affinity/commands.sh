#!/usr/bin/env bash
# ЛАБА 2.4 · Night Shift anti-affinity: доступность против жёсткости
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/17_2.4_pod_anti_affinity"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

# После DB-демо возвращаем node3 в общий worker-pool.
kubectl -n traffic-lab delete deploy/night-shift-postgres svc/night-shift-postgres --ignore-not-found
kubectl -n traffic-lab delete secret/night-shift-db configmap/night-shift-db-init --ignore-not-found
kubectl taint node node3 dedicated=database:NoSchedule- 2>/dev/null || true
kubectl label node node3 workload.boostmentor.dev/tier- 2>/dev/null || true

kubectl apply -k ./base
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl -n traffic-lab get pod -l app=night-shift -o wide
# preferred anti-affinity + soft spread: две реплики стараются разойтись.

kubectl -n traffic-lab patch deploy night-shift --type merge   --patch-file ./required-anti-affinity-patch.yaml
kubectl -n traffic-lab scale deploy night-shift --replicas=3
kubectl -n traffic-lab get pod -l app=night-shift -o wide
# На двух workers: две Running на разных нодах, третья Pending.

kubectl -n traffic-lab patch deploy night-shift --type=json   -p='[{"op":"remove","path":"/spec/template/spec/affinity/podAntiAffinity/requiredDuringSchedulingIgnoredDuringExecution"}]'
kubectl -n traffic-lab scale deploy night-shift --replicas=2
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
