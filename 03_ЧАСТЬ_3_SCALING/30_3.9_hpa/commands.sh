#!/usr/bin/env bash
# ЛАБА 3.9 · HPA на 4 панелях: 1 → 6 реплик по формуле
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl apply -k ./app
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl apply -f ./hpa_lab.yaml
kubectl -n traffic-lab get hpa night-shift -w
# Во втором терминале: несколько запросов запускают контролируемую нагрузку.
read -r -p "Night Shift URL (without trailing slash): " NIGHT_SHIFT_URL
for i in {1..8}; do curl -fsS "$NIGHT_SHIFT_URL/overload?sec=90" >/dev/null & done
kubectl -n traffic-lab get pods -l app=night-shift -w
