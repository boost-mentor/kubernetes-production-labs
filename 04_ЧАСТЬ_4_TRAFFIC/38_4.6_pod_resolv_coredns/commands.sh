#!/usr/bin/env bash
# ЛАБА 4.6 · resolv.conf пода: CoreDNS, search и ndots:5
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide     # → вот он, CoreDNS
kubectl -n traffic-lab exec client -- cat /etc/resolv.conf
# → nameserver <ClusterIP CoreDNS>
#   search traffic-lab.svc.cluster.local svc.cluster.local cluster.local
#   options ndots:5
kubectl -n traffic-lab exec client -- dig +short night-shift.traffic-lab.svc.cluster.local   # → ClusterIP
kubectl -n traffic-lab exec client -- dig +short night-shift                                 # → тот же IP — БЕЗ FQDN!
