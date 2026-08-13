#!/usr/bin/env bash
# ЛАБА 4.13 · Restore после failover: подтверждаем штатный сервис
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/45_4.13_keepalived_restore"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

HA_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/43_4.11_external_ha_setup/ha"
cd "$HA_DIR"
./show-state.sh
./restore-after-demo.sh
./show-state.sh
