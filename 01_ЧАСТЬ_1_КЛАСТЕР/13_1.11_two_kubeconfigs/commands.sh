#!/usr/bin/env bash
# ЛАБА 1.11 · Два доступа: exec-токен vs статичный сертификат
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl config view --raw -o json | python3 -m json.tool | grep -A5 '"exec"|client-certificate-data' | head -30
kubectl --context kubespray get nodes
kubectl --context yc-managed get nodes
# Managed context получает short-lived token через exec plugin; Kubespray
# kubeconfig содержит client certificate. Оба файла держим mode 0600.
