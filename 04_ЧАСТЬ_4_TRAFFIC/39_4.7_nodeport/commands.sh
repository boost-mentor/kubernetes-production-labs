#!/usr/bin/env bash
# ЛАБА 4.7 · NodePort: вход снаружи через ЛЮБУЮ ноду
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl apply -f ./night_shift.yaml
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl -n traffic-lab patch svc night-shift --type merge -p '{"spec":{"type":"NodePort"}}'
NODE_PORT="$(kubectl -n traffic-lab get svc night-shift -o jsonpath='{.spec.ports[0].nodePort}')"
read -r -p "public/floating IP любой Kubernetes-ноды: " NODE_PUBLIC_IP
curl -fsS "http://$NODE_PUBLIC_IP:$NODE_PORT/readyz"
kubectl -n traffic-lab get svc night-shift -o wide
