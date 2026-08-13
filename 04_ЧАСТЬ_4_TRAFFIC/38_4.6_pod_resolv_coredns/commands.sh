#!/usr/bin/env bash
# ЛАБА 4.6 · resolv.conf пода: CoreDNS, search и ndots:5
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/38_4.6_pod_resolv_coredns"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl apply -f ./night_shift.yaml
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl apply -f ./debug-client.yaml
kubectl -n traffic-lab wait --for=condition=Ready pod/client --timeout=180s

kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl -n traffic-lab exec client -- cat /etc/resolv.conf
kubectl -n traffic-lab exec client -- dig +short night-shift.traffic-lab.svc.cluster.local
kubectl -n traffic-lab exec client -- dig +search +short night-shift
# Короткое имя раскрывается через search list текущего namespace.
