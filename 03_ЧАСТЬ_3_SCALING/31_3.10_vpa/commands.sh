#!/usr/bin/env bash
# ЛАБА 3.10 · VPA: правда про аппетиты пода
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl apply -k ./base
./vpa-kit/install.sh
./vpa-kit/preflight.sh
kubectl apply -f ./vpa_lab.yaml
kubectl -n traffic-lab describe vpa night-shift | sed -n '/Recommendation:/,$p'
# updateMode=Off: рекомендация видна, поды не перезапускаются.
