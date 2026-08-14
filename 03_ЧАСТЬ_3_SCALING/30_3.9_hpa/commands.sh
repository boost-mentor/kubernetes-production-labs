#!/usr/bin/env bash
# ЛАБА 3.9 · HPA на 4 панелях: 1 → 6 реплик по формуле
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/30_3.9_hpa"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl apply -k ./app/overlays/recording
kubectl -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl apply -f ./debug-client.yaml
kubectl -n traffic-lab wait --for=condition=Ready pod/client --timeout=180s
kubectl apply -f ./hpa_lab.yaml
kubectl -n traffic-lab get hpa devops-may-cry
kubectl -n traffic-lab exec client -- sh -c   'for i in $(seq 1 8); do curl -fsS "http://devops-may-cry/overload?sec=90" >/dev/null & done; wait'
kubectl -n traffic-lab get hpa devops-may-cry -w
# HPA считает utilization от requests; Ctrl+C после роста реплик.
kubectl -n traffic-lab get pods -l app=devops-may-cry -w
