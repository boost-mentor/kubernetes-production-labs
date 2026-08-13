#!/usr/bin/env bash
# ЛАБА 3.2 · `memory: 128` — это сто двадцать восемь БАЙТ
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl run bad --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"bad","image":"nginx:1.27","resources":{"limits":{"memory":"128"}}}]}}'
kubectl get pod bad                # → НЕ Running (OOMKilled / CrashLoopBackOff)
kubectl describe pod bad | tail -5 # → limit memory: 128 ← БАЙТ, без суффикса
kubectl delete pod bad
