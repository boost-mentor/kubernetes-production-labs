#!/usr/bin/env bash
# ЛАБА 3.11 · Cluster Autoscaler: Pending рождает ноду
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cd ./terraform
cp terraform.tfvars.example terraform.tfvars
# В terraform.tfvars: enable_autoscaling=true, min=2, max=5.
terraform init
terraform validate
terraform plan -out=autoscaler.tfplan
terraform apply autoscaler.tfplan
yc managed-kubernetes node-group list

kubectl --context yc-managed apply -f ./night_shift.yaml
kubectl --context yc-managed -n traffic-lab scale deploy night-shift --replicas=20
kubectl --context yc-managed get nodes -w
# Cleanup нагрузки; сам managed stand удаляется один раз в финале части.
kubectl --context yc-managed -n traffic-lab scale deploy night-shift --replicas=2
