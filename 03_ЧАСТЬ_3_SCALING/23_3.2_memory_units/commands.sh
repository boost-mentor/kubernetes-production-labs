#!/usr/bin/env bash
# ЛАБА 3.2 · `memory: 128` — это сто двадцать восемь БАЙТ
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/23_3.2_memory_units"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl run bad --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"bad","image":"nginx:1.27","resources":{"limits":{"memory":"128"}}}]}}'
kubectl get pod bad                # → НЕ Running (OOMKilled / CrashLoopBackOff)
kubectl describe pod bad | tail -5 # → limit memory: 128 ← БАЙТ, без суффикса
kubectl delete pod bad
