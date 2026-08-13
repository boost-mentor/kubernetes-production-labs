#!/usr/bin/env bash
# ЛАБА 4.7 · NodePort: вход снаружи через ЛЮБУЮ ноду
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/39_4.7_nodeport"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl apply -f ./night_shift.yaml
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl -n traffic-lab patch svc night-shift --type merge -p '{"spec":{"type":"NodePort"}}'
NODE_PORT="$(kubectl -n traffic-lab get svc night-shift -o jsonpath='{.spec.ports[0].nodePort}')"
read -r -p "public/floating IP любой Kubernetes-ноды: " NODE_PUBLIC_IP
curl -fsS "http://$NODE_PUBLIC_IP:$NODE_PORT/readyz"
kubectl -n traffic-lab get svc night-shift -o wide
