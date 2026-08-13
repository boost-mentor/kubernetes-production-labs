#!/usr/bin/env bash
# ЛАБА 1.6 · verify-скрипт: «ноды живы» ≠ «кластер работает»
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl config use-context kubespray
bash ./verify_self_managed.sh
# → 10 проверок подряд: ноды, версии, системные поды, CNI, DNS,
#   создание пода, резолв изнутри, pod-to-pod, pod-to-service, события — все ✅
