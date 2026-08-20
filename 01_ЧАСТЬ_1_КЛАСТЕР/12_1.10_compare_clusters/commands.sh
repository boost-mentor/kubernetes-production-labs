#!/usr/bin/env bash
# ЛАБА 1.10 · Сплит-скрин: 5 сравнений managed vs self-managed
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/12_1.10_compare_clusters"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl --context yc-managed apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context yc-managed -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context yc-managed -n traffic-lab patch svc devops-may-cry --type merge -p '{"spec":{"type":"LoadBalancer"}}'

# 1. Где control-plane?
kubectl --context kubespray get nodes
kubectl --context yc-managed get nodes

# 2. Кто владеет etcd?
kubectl --context kubespray -n kube-system get pods | grep etcd
kubectl --context yc-managed -n kube-system get pods | grep etcd || true

# 3. Кто отвечает за сертификаты?
read -r -p "public/floating IP node1: " NODE1_PUBLIC_IP
ssh "root@$NODE1_PUBLIC_IP" 'sudo kubeadm certs check-expiration | head -12'

# 4. Кто даёт внешний адрес Service?
kubectl --context kubespray -n traffic-lab get svc devops-may-cry-metallb -o wide
kubectl --context yc-managed -n traffic-lab get svc devops-may-cry -w

# 5. Что видно в control plane облака?
yc managed-kubernetes cluster list
yc managed-kubernetes node-group list
# В браузере рядом: self-managed 5 VM в уроке и managed cluster в Yandex UI.

# 6. Как отличается доступ? Без --raw секреты замаскированы.
kubectl config get-contexts
kubectl config view --context yc-managed --minify -o yaml
kubectl config view --context kubespray --minify -o yaml
stat -f '%Sp %N' "$HOME/.kube/config"
