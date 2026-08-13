#!/usr/bin/env bash
# ЛАБА 3.10 · VPA: правда про аппетиты пода
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/31_3.10_vpa"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl apply -k ./base
./vpa-kit/install.sh
./vpa-kit/preflight.sh
kubectl apply -f ./vpa_lab.yaml
kubectl -n traffic-lab describe vpa night-shift | sed -n '/Recommendation:/,$p'
# updateMode=Off: рекомендация видна, поды не перезапускаются.
