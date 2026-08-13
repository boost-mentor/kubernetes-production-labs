#!/usr/bin/env bash
# ЛАБА 1.13 · Отказ ноды: балансировщик выкидывает мёртвый backend
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cd ha
./show-state.sh
./demo-failover.sh
./show-state.sh
