#!/usr/bin/env bash
# ЛАБА 2.1 · explain: два поля, а не четыре
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl explain pod.spec.affinity
# → FIELDS: nodeAffinity, podAffinity, podAntiAffinity
kubectl explain pod.spec.affinity.nodeAffinity
# → ровно ДВА поля:
#   preferredDuringSchedulingIgnoredDuringExecution
#   requiredDuringSchedulingIgnoredDuringExecution
kubectl explain pod.spec.affinity.podAntiAffinity
# → те же ДВА поля, тот же хвост IgnoredDuringExecution
