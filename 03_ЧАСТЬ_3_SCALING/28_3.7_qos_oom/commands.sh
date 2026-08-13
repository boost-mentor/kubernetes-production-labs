#!/usr/bin/env bash
# ЛАБА 3.7 · Симуляция: кого съест OOM-Killer (QoS)
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./requests_limits.yaml
kubectl -n traffic-lab wait --for=condition=Available deploy/night-shift-guaranteed deploy/night-shift-burstable deploy/night-shift-besteffort --timeout=180s
kubectl -n traffic-lab get pods -l lab.boostmentor.dev/qos -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass,NODE:.spec.nodeName'
kubectl -n traffic-lab get deploy night-shift-guaranteed night-shift-burstable night-shift-besteffort -o custom-columns='NAME:.metadata.name,REQUESTS:.spec.template.spec.containers[0].resources.requests,LIMITS:.spec.template.spec.containers[0].resources.limits'
# На общем стенде не создаём искусственный node MemoryPressure: это может
# выбить control-plane workload. QoS доказан API; реальный kill подтверждаем
# отдельной cgroup-ограниченной лабой 3.5 и Events/Last State.
