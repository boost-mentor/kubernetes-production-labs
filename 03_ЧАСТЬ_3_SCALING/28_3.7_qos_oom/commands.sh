#!/usr/bin/env bash
# ЛАБА 3.7 · QoS без мифа «BestEffort всегда умирает первым»
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/28_3.7_qos_oom"
cd "$LAB_DIR" || exit

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./requests_limits.yaml
kubectl -n traffic-lab wait --for=condition=Available deploy/devops-may-cry-guaranteed deploy/devops-may-cry-burstable deploy/devops-may-cry-besteffort --timeout=180s
kubectl -n traffic-lab get pods -l lab.boostmentor.dev/qos -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass,NODE:.spec.nodeName'
kubectl -n traffic-lab get deploy devops-may-cry-guaranteed devops-may-cry-burstable devops-may-cry-besteffort -o custom-columns='NAME:.metadata.name,REQUESTS:.spec.template.spec.containers[0].resources.requests,LIMITS:.spec.template.spec.containers[0].resources.limits'

# Проверяем каждый класс как acceptance criterion, а не «похоже на правду».
for expected in \
  guaranteed:Guaranteed \
  burstable:Burstable \
  best-effort:BestEffort; do
  label="${expected%%:*}"
  wanted="${expected##*:}"
  pod="$(kubectl -n traffic-lab get pod \
    -l "lab.boostmentor.dev/qos=$label" \
    -o jsonpath='{.items[0].metadata.name}')"
  actual="$(kubectl -n traffic-lab get pod "$pod" \
    -o jsonpath='{.status.qosClass}')"
  printf '%-12s expected=%-10s actual=%s\n' "$label" "$wanted" "$actual"
  test "$actual" = "$wanted"
done

# Что доказано: kubelet присвоил три QoS-класса одному и тому же image.
# Что НЕ доказано: абсолютный порядок kill. При node-pressure kubelet ещё смотрит,
# превышает ли pod request, какой у него Priority и насколько usage превышает request.
# Реальный cgroup OOM уже доказан в лабе 3.5 через Last State + exit 137.

# Restore только своих трёх лабораторных Deployment.
kubectl -n traffic-lab delete -f ./requests_limits.yaml --ignore-not-found
