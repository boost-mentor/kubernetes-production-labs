#!/usr/bin/env bash
# ЛАБА 1.11 · Два доступа: exec-токен vs статичный сертификат
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/13_1.11_two_kubeconfigs"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl config view --raw -o json | python3 -m json.tool | grep -A5 '"exec"|client-certificate-data' | head -30
kubectl --context kubespray get nodes
kubectl --context yc-managed get nodes
# Managed context получает short-lived token через exec plugin; Kubespray
# kubeconfig содержит client certificate. Оба файла держим mode 0600.
