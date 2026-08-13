#!/usr/bin/env bash
# ЛАБА 4.9 · ssh на ноду: Service — это правила, и вот они
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

SERVICE_IP="$(kubectl -n traffic-lab get svc night-shift -o jsonpath='{.spec.clusterIP}')"
read -r -p "public/floating IP Kubernetes-ноды: " NODE_PUBLIC_IP
ssh "root@$NODE_PUBLIC_IP" "sudo ipvsadm -Ln | grep -A4 '$SERVICE_IP' || sudo nft list ruleset | grep -A3 '$SERVICE_IP'"
kubectl -n traffic-lab get endpointslice -l kubernetes.io/service-name=night-shift -o wide
# kube-proxy IPVS выбирает backend из EndpointSlice; приложение не знает ClusterIP.
