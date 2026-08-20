#!/usr/bin/env bash
# ЛАБА 3.0 · Metrics Server через роль Kubespray, затем три доказательства
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/21_3.0_metrics_server"
cd "$LAB_DIR" || exit

KUBESPRAY_CONFIG="$REPO_ROOT/kubespray"
KUBESPRAY_UPSTREAM="$REPO_ROOT/vendor/kubespray"
KUBESPRAY_INVENTORY="$KUBESPRAY_CONFIG/inventory/video2/inventory.ini"
ANSIBLE_PLAYBOOK="$REPO_ROOT/.venv/bin/ansible-playbook"

# До изменения: Metrics API ещё нет. NotFound здесь — ожидаемый факт,
# а не причина добавлять случайный YAML из main.
kubectl get apiservice v1beta1.metrics.k8s.io || true
kubectl top nodes || true

# Видим контракт до запуска: pinned upstream, inventory и два флага addon.
test "$(git -C "$KUBESPRAY_UPSTREAM" describe --tags --exact-match)" = "v2.31.0"
test -x "$ANSIBLE_PLAYBOOK"
test -f "$KUBESPRAY_INVENTORY"
sed -n '1,80p' ./addons-metrics-server.yml
install -m 0644 ./addons-metrics-server.yml \
  "$KUBESPRAY_CONFIG/inventory/video2/group_vars/k8s_cluster/addons.yml"

# Не deploy.sh: запускаем конкретную upstream-роль прямо.
cd "$KUBESPRAY_UPSTREAM" || exit
"$ANSIBLE_PLAYBOOK" -i "$KUBESPRAY_INVENTORY" \
  ./cluster.yml --become --tags metrics_server
cd "$LAB_DIR" || exit

# Доказательство 1: Deployment раскатился, а в args виден лабораторный TLS-компромисс.
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
kubectl -n kube-system get deploy metrics-server \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'

# Доказательство 2: aggregated APIService перешёл в Available=True.
kubectl wait --for=condition=Available \
  apiservice/v1beta1.metrics.k8s.io --timeout=180s
kubectl get apiservice v1beta1.metrics.k8s.io

# Доказательство 3: сырой API возвращает samples, а kubectl top только удобно их форматирует.
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes \
  | jq -r '.items[] | [.metadata.name,.usage.cpu,.usage.memory] | @tsv'
kubectl top nodes
kubectl top pods -A --sort-by=memory | head -15

# Production caveat: этот стенд явно уступает TLS-проверкой ради демо.
# В production нужны CA-signed kubelet serving certs и caBundle APIService; один
# зелёный `kubectl top` не доказывает корректность requests/limits и HPA.
