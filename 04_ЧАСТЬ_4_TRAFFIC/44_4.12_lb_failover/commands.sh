#!/usr/bin/env bash
# ЛАБА 4.12 · Failover внешнего LB: VIP переезжает на standby
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/44_4.12_lb_failover"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

HA_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/43_4.11_external_ha_setup/ha"
cd "$HA_DIR"
./show-state.sh
./demo-failover.sh
./show-state.sh
