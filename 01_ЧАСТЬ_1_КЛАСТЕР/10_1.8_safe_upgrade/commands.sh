#!/usr/bin/env bash
# ЛАБА 1.8 · Безопасное обновление узла: cordon → drain → uncordon
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl apply -k ./app
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
bash ./pre_upgrade_check.sh

kubectl cordon node2
kubectl get nodes
kubectl -n traffic-lab get pods -l app=night-shift -o wide
# cordon запрещает новое размещение, но не выселяет уже работающий pod.

kubectl drain node2 --ignore-daemonsets --delete-emptydir-data
kubectl -n traffic-lab get pods -l app=night-shift -o wide
kubectl -n traffic-lab get pdb night-shift
# PDB сохранил минимум один Ready pod; tmp emptyDir у приложения disposable.

kubectl uncordon node2
bash ./post_upgrade_check.sh
kubectl get nodes
# Scheduler не перетасовывает живые pod обратно только ради красоты.
