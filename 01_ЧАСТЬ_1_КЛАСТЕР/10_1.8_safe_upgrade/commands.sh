#!/usr/bin/env bash
# ЛАБА 1.8 · Безопасное обновление узла: cordon → drain → uncordon
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/10_1.8_safe_upgrade"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl apply -k ./app
kubectl -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
bash ./pre_upgrade_check.sh

kubectl cordon node2
kubectl get nodes
kubectl -n traffic-lab get pods -l app=devops-may-cry -o wide
# cordon запрещает новое размещение, но не выселяет уже работающий pod.

kubectl drain node2 --ignore-daemonsets --delete-emptydir-data
kubectl -n traffic-lab get pods -l app=devops-may-cry -o wide
kubectl -n traffic-lab get pdb devops-may-cry
# PDB сохранил минимум один Ready pod; tmp emptyDir у приложения disposable.

kubectl uncordon node2
bash ./post_upgrade_check.sh
kubectl get nodes
# Scheduler не перетасовывает живые pod обратно только ради красоты.
