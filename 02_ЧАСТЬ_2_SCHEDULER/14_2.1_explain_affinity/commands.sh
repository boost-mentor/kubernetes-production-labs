#!/usr/bin/env bash
# ЛАБА 2.1 · explain: два поля, а не четыре
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/14_2.1_explain_affinity"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl explain pod.spec.affinity
# → FIELDS: nodeAffinity, podAffinity, podAntiAffinity
kubectl explain pod.spec.affinity.nodeAffinity
# → ровно ДВА поля:
#   preferredDuringSchedulingIgnoredDuringExecution
#   requiredDuringSchedulingIgnoredDuringExecution
kubectl explain pod.spec.affinity.podAntiAffinity
# → те же ДВА поля, тот же хвост IgnoredDuringExecution
