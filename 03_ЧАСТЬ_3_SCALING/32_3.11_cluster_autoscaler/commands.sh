#!/usr/bin/env bash
# ЛАБА 3.11 · Cluster Autoscaler: Pending рождает ноду
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/32_3.11_cluster_autoscaler"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

MANIFEST="$LAB_DIR/devops_may_cry.yaml"
cd "$LAB_DIR/terraform"
cp terraform.tfvars.example terraform.tfvars
# В terraform.tfvars: enable_autoscaling=true, min=2, max=5.
terraform init
terraform validate
terraform plan -out=autoscaler.tfplan
terraform apply autoscaler.tfplan
yc managed-kubernetes node-group list

kubectl --context yc-managed apply -f "$MANIFEST"
kubectl --context yc-managed -n traffic-lab patch deploy devops-may-cry --type=json   -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"1500m"}]'
kubectl --context yc-managed -n traffic-lab scale deploy devops-may-cry --replicas=3
kubectl --context yc-managed -n traffic-lab get pods -l app=devops-may-cry -w
# Одна реплика гарантированно Pending на двух nodes по 2 vCPU; Ctrl+C.
PENDING_POD=$(kubectl --context yc-managed -n traffic-lab get pod -l app=devops-may-cry   --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')
kubectl --context yc-managed -n traffic-lab describe pod "$PENDING_POD" | sed -n '/Events:/,$p'
kubectl --context yc-managed get nodes -w
# Ctrl+C, когда новая нода Ready и Pending-под перешёл в Running.
# Cleanup нагрузки; сам managed stand удаляется один раз в финале части.
kubectl --context yc-managed -n traffic-lab patch deploy devops-may-cry --type=json   -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"}]'
kubectl --context yc-managed -n traffic-lab scale deploy devops-may-cry --replicas=2
