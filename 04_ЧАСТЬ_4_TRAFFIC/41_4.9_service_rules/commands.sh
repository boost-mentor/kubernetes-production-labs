#!/usr/bin/env bash
# ЛАБА 4.9 · ssh на ноду: Service — это правила, и вот они
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/41_4.9_service_rules"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

SERVICE_IP="$(kubectl -n traffic-lab get svc night-shift -o jsonpath='{.spec.clusterIP}')"
read -r -p "public/floating IP Kubernetes-ноды: " NODE_PUBLIC_IP
ssh "root@$NODE_PUBLIC_IP" "sudo ipvsadm -Ln | grep -A4 '$SERVICE_IP' || sudo nft list ruleset | grep -A3 '$SERVICE_IP'"
kubectl -n traffic-lab get endpointslice -l kubernetes.io/service-name=night-shift -o wide
# kube-proxy IPVS выбирает backend из EndpointSlice; приложение не знает ClusterIP.
