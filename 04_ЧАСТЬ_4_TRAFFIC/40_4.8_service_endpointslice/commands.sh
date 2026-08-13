#!/usr/bin/env bash
# ЛАБА 4.8 · Service ≠ процесс: ClusterIP, EndpointSlice и смерть пода
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/40_4.8_service_endpointslice"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

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
