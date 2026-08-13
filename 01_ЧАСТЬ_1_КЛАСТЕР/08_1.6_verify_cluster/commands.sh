#!/usr/bin/env bash
# ЛАБА 1.6 · verify-скрипт: «ноды живы» ≠ «кластер работает»
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/08_1.6_verify_cluster"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl config use-context kubespray
bash ./verify_self_managed.sh
# → 10 проверок подряд: ноды, версии, системные поды, CNI, DNS,
#   создание пода, резолв изнутри, pod-to-pod, pod-to-service, события — все ✅
