#!/usr/bin/env bash
# ЛАБА 4.8 · Service ≠ процесс: ClusterIP, EndpointSlice и смерть пода
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl -n traffic-lab get svc night-shift -o wide            # → ClusterIP: 10.233.x.x
kubectl -n traffic-lab get pod -l app=night-shift -o wide     # → IP подов — ДРУГИЕ (из Pod CIDR)
kubectl -n traffic-lab exec client -- curl -s night-shift | head -1   # → 200


kubectl -n traffic-lab get endpointslice -l kubernetes.io/service-name=night-shift -o wide
# → ВОТ реальные адреса: два ready endpoint = IP подов


POD=$(kubectl -n traffic-lab get pod -l app=night-shift -o jsonpath='{.items[0].metadata.name}')
kubectl -n traffic-lab delete pod "$POD" --wait=false
kubectl -n traffic-lab get endpointslice -l kubernetes.io/service-name=night-shift -w
# → старый endpoint исчез → появился НОВЫЙ IP (пересозданный под)  (Ctrl+C)
kubectl -n traffic-lab get svc night-shift    # → ClusterIP ТОТ ЖЕ, не дрогнул
