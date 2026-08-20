# VIDEO2 · Часть 3 · команды для записи

Это единственный командник для основной записи части 3. Иди сверху вниз и копируй только блок с ID, который сейчас показан в суфлёре. Команды выполняются по блокам, не весь файл целиком.

Часть 3 продолжает два стенда из части 1: `kubespray` для лабораторий с cgroup/kubelet и `yc-managed` для Cluster Autoscaler. Реальные адреса и ключи читаются из локального `recording/.recording.env`; их не печатаем и не коммитим.

## V2-C3-S01-C01 · Зафиксировать контекст и состояние Metrics API до установки

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit
set -a
source recording/.recording.env
set +a
KUBESPRAY_ROOT="$REPO_ROOT/kubespray"
KUBESPRAY_UPSTREAM="$KUBESPRAY_ROOT/vendor/kubespray"
KUBESPRAY_INVENTORY="$KUBESPRAY_ROOT/inventory/video2/inventory.ini"
ANSIBLE_PLAYBOOK="$KUBESPRAY_ROOT/.venv/bin/ansible-playbook"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
test "$(git -C "$KUBESPRAY_UPSTREAM" describe --tags --exact-match)" = "v2.31.0"
kubectl --context "$SELF_CONTEXT" get nodes
kubectl --context "$SELF_CONTEXT" get apiservice v1beta1.metrics.k8s.io || true
kubectl --context "$SELF_CONTEXT" top nodes || true
sed -n '1,80p' 03_ЧАСТЬ_3_SCALING/21_3.0_metrics_server/addons-metrics-server.yml
```

Ожидаю: три Ready-ноды self-managed кластера; до установки Metrics API либо отсутствует, либо `kubectl top` сообщает, что API недоступен. Pinned upstream — ровно `v2.31.0`.

## V2-C3-S01-C02 · Установить Metrics Server ролью Kubespray и доказать API

```bash
install -m 0644 \
  "$REPO_ROOT/03_ЧАСТЬ_3_SCALING/21_3.0_metrics_server/addons-metrics-server.yml" \
  "$KUBESPRAY_ROOT/inventory/video2/group_vars/k8s_cluster/addons.yml"
pushd "$KUBESPRAY_UPSTREAM" >/dev/null
"$ANSIBLE_PLAYBOOK" -i "$KUBESPRAY_INVENTORY" \
  cluster.yml \
  --become --private-key "$SSH_KEY" --tags metrics_server
popd >/dev/null
kubectl --context "$SELF_CONTEXT" -n kube-system \
  rollout status deploy/metrics-server --timeout=180s
kubectl --context "$SELF_CONTEXT" wait --for=condition=Available \
  apiservice/v1beta1.metrics.k8s.io --timeout=180s
kubectl --context "$SELF_CONTEXT" get apiservice v1beta1.metrics.k8s.io
kubectl --context "$SELF_CONTEXT" get --raw /apis/metrics.k8s.io/v1beta1/nodes \
  | jq -r '.items[] | [.metadata.name,.usage.cpu,.usage.memory] | @tsv'
kubectl --context "$SELF_CONTEXT" top nodes
kubectl --context "$SELF_CONTEXT" top pods -A --sort-by=memory | head -15
```

Ожидаю: `PLAY RECAP` без failed, Deployment доступен, APIService имеет `Available=True`, сырой Metrics API и `kubectl top` возвращают samples.

## V2-C3-S02-C01 · Применить requests/limits и увидеть решение планировщика

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/22_3.1_requests_limits_cgroup"
cd "$LAB_DIR" || exit
kubectl --context "$SELF_CONTEXT" create namespace traffic-lab \
  --dry-run=client -o yaml | kubectl --context "$SELF_CONTEXT" apply -f -
kubectl --context "$SELF_CONTEXT" apply -f requests_limits.yaml
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  rollout status deploy/devops-may-cry-burstable --timeout=180s
POD="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod \
  -l app=devops-may-cry-burstable -o jsonpath='{.items[0].metadata.name}')"
NODE="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$POD" \
  -o jsonpath='{.spec.nodeName}')"
kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$POD" \
  -o custom-columns='NAME:.metadata.name,NODE:.spec.nodeName,QOS:.status.qosClass,REQUEST_CPU:.spec.containers[0].resources.requests.cpu,LIMIT_CPU:.spec.containers[0].resources.limits.cpu,REQUEST_MEM:.spec.containers[0].resources.requests.memory,LIMIT_MEM:.spec.containers[0].resources.limits.memory'
kubectl --context "$SELF_CONTEXT" describe node "$NODE" \
  | sed -n '/Allocated resources:/,/Events:/p'
```

Ожидаю: Pod `Burstable`, request `100m/64Mi`, limit `500m/256Mi`; в `Allocated resources` ноды requests и limits считаются отдельно.

## V2-C3-S02-C02 · Прочитать реальные cgroup-ограничения через runtime

```bash
kubectl --context "$SELF_CONTEXT" -n traffic-lab exec "$POD" \
  -- cat /sys/fs/cgroup/memory.max || true
CONTAINER_ID="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$POD" \
  -o jsonpath='{.status.containerStatuses[0].containerID}' | sed 's#^[^:]*://##')"
printf 'pod=%s node=%s container=%s\n' "$POD" "$NODE" "$CONTAINER_ID"
case "$NODE" in
  node1) NODE_SSH_HOST="${NODE1_SSH_HOST:?fill NODE1_SSH_HOST}" ;;
  node2) NODE_SSH_HOST="${NODE2_SSH_HOST:?fill NODE2_SSH_HOST}" ;;
  node3) NODE_SSH_HOST="${NODE3_SSH_HOST:?fill NODE3_SSH_HOST}" ;;
  *) printf 'unexpected node: %s\n' "$NODE" >&2; exit 1 ;;
esac
SSH_USER="${VIDEO2_SSH_USER:-root}"
REMOTE_PID="$(ssh -i "$SSH_KEY" "$SSH_USER@$NODE_SSH_HOST" \
  "sudo crictl inspect '$CONTAINER_ID'" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["pid"])')"
ssh -i "$SSH_KEY" "$SSH_USER@$NODE_SSH_HOST" \
  "sudo nsenter -t '$REMOTE_PID' -m cat /sys/fs/cgroup/memory.max; sudo nsenter -t '$REMOTE_PID' -m cat /sys/fs/cgroup/cpu.max"
```

Ожидаю: `kubectl exec` не находит `cat` в distroless-образе; через runtime видны конечный `memory.max` для 256Mi и CPU quota, соответствующая limit `500m`.

## V2-C3-S03-C01 · Доказать, что memory 128 означает 128 байт

```bash
kubectl --context "$SELF_CONTEXT" -n traffic-lab delete pod bad-memory-unit \
  --ignore-not-found --wait=true
kubectl --context "$SELF_CONTEXT" -n traffic-lab run bad-memory-unit \
  --image='ghcr.io/boost-mentor/devops-may-cry@sha256:41439418d570649055117277a53b17b91fb40dad33dc3fa6b8a151fe68f86ca7' \
  --restart=Always \
  --overrides='{"spec":{"automountServiceAccountToken":false,"securityContext":{"runAsNonRoot":true,"runAsUser":65532,"runAsGroup":65532,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"bad-memory-unit","image":"ghcr.io/boost-mentor/devops-may-cry@sha256:41439418d570649055117277a53b17b91fb40dad33dc3fa6b8a151fe68f86ca7","resources":{"limits":{"memory":"128"}},"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsNonRoot":true,"runAsUser":65532,"runAsGroup":65532}}]}}'
for _attempt in $(seq 1 30); do
  REASON="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod bad-memory-unit \
    -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)"
  test "$REASON" = "OOMKilled" && break
  sleep 2
done
kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod bad-memory-unit \
  -o jsonpath='limit={.spec.containers[0].resources.limits.memory}{" reason="}{.status.containerStatuses[0].lastState.terminated.reason}{" exit="}{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}'
test "$REASON" = "OOMKilled"
kubectl --context "$SELF_CONTEXT" -n traffic-lab delete pod bad-memory-unit --wait=true
```

Ожидаю: в объекте записан limit `128`, процесс завершается `OOMKilled` с exit code `137`; после доказательства Pod удалён.

## V2-C3-S04-C01 · Сравнить Capacity и Allocatable на worker-ноде

```bash
kubectl --context "$SELF_CONTEXT" describe node node2 \
  | sed -n '/Capacity:/,/System Info:/p'
kubectl --context "$SELF_CONTEXT" get node node2 \
  -o jsonpath='capacity={.status.capacity}{"\n"}allocatable={.status.allocatable}{"\n"}'
kubectl --context "$SELF_CONTEXT" describe node node2 \
  | sed -n '/Allocated resources:/,/Events:/p'
```

Ожидаю: Node публикует оба набора значений; Allocatable отражает доступное Pod'ам после резервов и порогов kubelet, а `Allocated resources` показывает сумму requests/limits уже назначенных Pod'ов.

## V2-C3-S05-C01 · Показать overcommit без искусственного отказа ноды

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/25_3.4_overcommit"
cd "$LAB_DIR" || exit
kubectl --context "$SELF_CONTEXT" apply -f requests_limits.yaml
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  scale deploy/devops-may-cry-burstable --replicas=12
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  rollout status deploy/devops-may-cry-burstable --timeout=180s
for node in node2 node3; do
  printf '\n=== %s ===\n' "$node"
  kubectl --context "$SELF_CONTEXT" describe node "$node" \
    | sed -n '/Allocated resources:/,/Events:/p'
done
kubectl --context "$SELF_CONTEXT" -n traffic-lab get pods \
  -l app=devops-may-cry-burstable -o wide
kubectl --context "$SELF_CONTEXT" delete -f requests_limits.yaml --ignore-not-found
```

Ожидаю: все 12 Pod'ов планируются, потому что помещается сумма requests; сумма CPU limits на worker-нодах может быть выше 100%. В конце три лабораторных Deployment удалены.

## V2-C3-S06-C01 · Воспроизвести cgroup OOM на DEVOPS MAY CRY

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/26_3.5_oomkilled"
cd "$LAB_DIR" || exit
kubectl --context "$SELF_CONTEXT" apply -f oom_cpu_demo.yaml
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  delete deploy devops-may-cry-throttled --ignore-not-found
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  rollout status deploy/devops-may-cry-oom --timeout=180s
OOM_POD="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod \
  -l app=devops-may-cry-oom -o jsonpath='{.items[0].metadata.name}')"
OOM_IP="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$OOM_POD" \
  -o jsonpath='{.status.podIP}')"
IMAGE="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get deploy devops-may-cry-oom \
  -o jsonpath='{.spec.template.spec.containers[0].image}')"
RESTARTS_BEFORE="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$OOM_POD" \
  -o jsonpath='{.status.containerStatuses[0].restartCount}')"
kubectl --context "$SELF_CONTEXT" -n traffic-lab run wound-trigger \
  --rm -i --restart=Never --image="$IMAGE" \
  --env="HEALTHCHECK_URL=http://$OOM_IP:8080/wound?mb=160" \
  --command -- /devops-may-cry -healthcheck || true
for _attempt in $(seq 1 30); do
  RESTARTS_AFTER="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$OOM_POD" \
    -o jsonpath='{.status.containerStatuses[0].restartCount}')"
  test "$RESTARTS_AFTER" -gt "$RESTARTS_BEFORE" && break
  sleep 2
done
test "$RESTARTS_AFTER" -gt "$RESTARTS_BEFORE"
```

Ожидаю: запрос к лабораторному `/wound` превышает limit `96Mi`, соединение может оборваться, а restartCount основного Pod'а увеличивается.

## V2-C3-S06-C02 · Доказать OOMKilled в Pod status и kernel log

```bash
kubectl --context "$SELF_CONTEXT" -n traffic-lab describe pod "$OOM_POD" \
  | sed -n '/Last State:/,/Ready:/p'
kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$OOM_POD" \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{" exit="}{.status.containerStatuses[0].lastState.terminated.exitCode}{" restarts="}{.status.containerStatuses[0].restartCount}{"\n"}'
NODE="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$OOM_POD" \
  -o jsonpath='{.spec.nodeName}')"
case "$NODE" in
  node1) NODE_SSH_HOST="${NODE1_SSH_HOST:?fill NODE1_SSH_HOST}" ;;
  node2) NODE_SSH_HOST="${NODE2_SSH_HOST:?fill NODE2_SSH_HOST}" ;;
  node3) NODE_SSH_HOST="${NODE3_SSH_HOST:?fill NODE3_SSH_HOST}" ;;
  *) printf 'unexpected node: %s\n' "$NODE" >&2; exit 1 ;;
esac
SSH_USER="${VIDEO2_SSH_USER:-root}"
ssh -i "$SSH_KEY" "$SSH_USER@$NODE_SSH_HOST" \
  'sudo dmesg -T | grep -iE "memory cgroup out of memory|killed process" | tail -5' || true
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  delete deploy devops-may-cry-oom --ignore-not-found
```

Ожидаю: `Last State` содержит `Reason: OOMKilled` и exit code `137`; kernel log может добавить строку cgroup OOM, но главным переносимым доказательством остаётся Pod status. Workload удалён.

## V2-C3-S07-C01 · Доказать CPU throttling счётчиком, а не перезапуском

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/27_3.6_cpu_throttling"
cd "$LAB_DIR" || exit
kubectl --context "$SELF_CONTEXT" apply -f oom_cpu_demo.yaml
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  delete deploy devops-may-cry-oom --ignore-not-found
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  rollout status deploy/devops-may-cry-throttled --timeout=180s
CPU_POD="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod \
  -l app=devops-may-cry-throttled -o jsonpath='{.items[0].metadata.name}')"
CPU_IP="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$CPU_POD" \
  -o jsonpath='{.status.podIP}')"
IMAGE="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get deploy devops-may-cry-throttled \
  -o jsonpath='{.spec.template.spec.containers[0].image}')"
NODE="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$CPU_POD" \
  -o jsonpath='{.spec.nodeName}')"
BEFORE="$(kubectl --context "$SELF_CONTEXT" get --raw "/api/v1/nodes/$NODE/proxy/metrics/cadvisor" \
  | grep 'container_cpu_cfs_throttled_periods_total' \
  | grep 'container="devops-may-cry"' | grep "pod=\"$CPU_POD\"" \
  | awk '{print $2}' | head -1)"
test -n "$BEFORE"
kubectl --context "$SELF_CONTEXT" -n traffic-lab run overload-trigger \
  --rm -i --restart=Never --image="$IMAGE" \
  --env="HEALTHCHECK_URL=http://$CPU_IP:8080/overload?sec=120" \
  --command -- /devops-may-cry -healthcheck
sleep 20
kubectl --context "$SELF_CONTEXT" -n traffic-lab top pod "$CPU_POD"
AFTER="$(kubectl --context "$SELF_CONTEXT" get --raw "/api/v1/nodes/$NODE/proxy/metrics/cadvisor" \
  | grep 'container_cpu_cfs_throttled_periods_total' \
  | grep 'container="devops-may-cry"' | grep "pod=\"$CPU_POD\"" \
  | awk '{print $2}' | head -1)"
RESTARTS="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$CPU_POD" \
  -o jsonpath='{.status.containerStatuses[0].restartCount}')"
printf 'throttled periods: before=%s after=%s; restarts=%s\n' \
  "$BEFORE" "$AFTER" "$RESTARTS"
awk -v before="$BEFORE" -v after="$AFTER" 'BEGIN { exit !(after > before) }'
test "$RESTARTS" -eq 0
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  delete deploy devops-may-cry-throttled --ignore-not-found
```

Ожидаю: throttled-period counter увеличивается, Pod остаётся Running, restartCount равен нулю. CPU limit замедлил процесс, но не убил его.

## V2-C3-S08-C01 · Проверить три QoS-класса на одном image

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/28_3.7_qos_oom"
cd "$LAB_DIR" || exit
kubectl --context "$SELF_CONTEXT" apply -f requests_limits.yaml
kubectl --context "$SELF_CONTEXT" -n traffic-lab wait --for=condition=Available \
  deploy/devops-may-cry-guaranteed \
  deploy/devops-may-cry-burstable \
  deploy/devops-may-cry-besteffort --timeout=180s
kubectl --context "$SELF_CONTEXT" -n traffic-lab get pods \
  -l lab.boostmentor.dev/qos \
  -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass,NODE:.spec.nodeName'
for expected in \
  guaranteed:Guaranteed \
  burstable:Burstable \
  best-effort:BestEffort; do
  label="${expected%%:*}"
  wanted="${expected##*:}"
  pod="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod \
    -l "lab.boostmentor.dev/qos=$label" \
    -o jsonpath='{.items[0].metadata.name}')"
  actual="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod "$pod" \
    -o jsonpath='{.status.qosClass}')"
  printf '%-12s expected=%-10s actual=%s\n' "$label" "$wanted" "$actual"
  test "$actual" = "$wanted"
done
kubectl --context "$SELF_CONTEXT" delete -f requests_limits.yaml --ignore-not-found
```

Ожидаю: один и тот же immutable image получает классы `Guaranteed`, `Burstable`, `BestEffort` только из-за разных resources; все три проверки проходят, затем workload удалён.

## V2-C3-S09-C01 · Получить Evicted без давления на всю ноду

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/29_3.8_eviction"
cd "$LAB_DIR" || exit
kubectl --context "$SELF_CONTEXT" get nodes \
  -o custom-columns='NAME:.metadata.name,MEMORY:.status.conditions[?(@.type=="MemoryPressure")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,PID:.status.conditions[?(@.type=="PIDPressure")].status'
sed -n '1,220p' eviction-demo.yaml
kubectl --context "$SELF_CONTEXT" apply -f eviction-demo.yaml
kubectl --context "$SELF_CONTEXT" -n traffic-lab wait \
  --for=jsonpath='{.status.reason}'=Evicted \
  pod/ephemeral-storage-hog --timeout=300s
kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod ephemeral-storage-hog \
  -o jsonpath='phase={.status.phase}{" reason="}{.status.reason}{"\nmessage="}{.status.message}{"\n"}'
test "$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod ephemeral-storage-hog \
  -o jsonpath='{.status.reason}')" = "Evicted"
kubectl --context "$SELF_CONTEXT" -n traffic-lab get events \
  --field-selector involvedObject.name=ephemeral-storage-hog \
  --sort-by=.lastTimestamp
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  delete pod ephemeral-storage-hog --ignore-not-found
```

Ожидаю: отдельный Pod получает phase `Failed`, reason `Evicted` из-за превышения своего ephemeral-storage limit; NodePressure не создаётся намеренно. Pod удалён.

## V2-C3-S10-C01 · Подготовить HPA с Metrics API и контролируемым endpoint

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/30_3.9_hpa"
cd "$LAB_DIR" || exit
kubectl --context "$SELF_CONTEXT" apply -k app/overlays/recording
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  rollout status deploy/devops-may-cry --timeout=180s
kubectl --context "$SELF_CONTEXT" apply -f debug-client.yaml
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  wait --for=condition=Ready pod/client --timeout=180s
kubectl --context "$SELF_CONTEXT" apply -f hpa_lab.yaml
CURRENT_UTILIZATION=""
for _attempt in $(seq 1 18); do
  CURRENT_UTILIZATION="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab \
    get hpa devops-may-cry \
    -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' \
    2>/dev/null || true)"
  test -n "$CURRENT_UTILIZATION" && break
  sleep 5
done
test -n "$CURRENT_UTILIZATION"
kubectl --context "$SELF_CONTEXT" -n traffic-lab get hpa devops-may-cry
kubectl --context "$SELF_CONTEXT" -n traffic-lab get deploy devops-may-cry \
  -o custom-columns='NAME:.metadata.name,REPLICAS:.status.readyReplicas,REQUEST_CPU:.spec.template.spec.containers[0].resources.requests.cpu'
```

Ожидаю: Deployment имеет две Ready-реплики и CPU request `100m`; HPA видит текущую метрику, target `50%`, min `2`, max `6`.

## V2-C3-S10-C02 · Создать CPU-нагрузку и доказать горизонтальное масштабирование

```bash
kubectl --context "$SELF_CONTEXT" -n traffic-lab exec client -- sh -c \
  'for i in $(seq 1 8); do curl -fsS "http://devops-may-cry/overload?sec=90" >/dev/null & done; wait'
for _attempt in $(seq 1 24); do
  kubectl --context "$SELF_CONTEXT" -n traffic-lab get hpa devops-may-cry
  DESIRED="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get hpa devops-may-cry \
    -o jsonpath='{.status.desiredReplicas}')"
  test "${DESIRED:-0}" -gt 2 && break
  sleep 5
done
test "$DESIRED" -gt 2
kubectl --context "$SELF_CONTEXT" -n traffic-lab get pods \
  -l app=devops-may-cry -o wide
kubectl --context "$SELF_CONTEXT" -n traffic-lab delete hpa devops-may-cry
kubectl --context "$SELF_CONTEXT" -n traffic-lab scale \
  deploy/devops-may-cry --replicas=2
kubectl --context "$SELF_CONTEXT" -n traffic-lab delete pod client --wait=true
```

Ожидаю: CPU utilization превышает target, desiredReplicas становится больше двух, появляются дополнительные Pod'ы, но не больше шести. После доказательства HPA и клиент удалены, Deployment возвращён к двум репликам.

## V2-C3-S11-C01 · Установить только VPA recommender из pinned source

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/31_3.10_vpa"
cd "$LAB_DIR" || exit
kubectl --context "$SELF_CONTEXT" apply -k base
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  delete hpa devops-may-cry --ignore-not-found
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  rollout status deploy/devops-may-cry --timeout=180s
VPA_VERSION="1.7.0"
VPA_COMMIT="6a616ea0c5ea0cb6111240073a9273b3467c064e"
VPA_SOURCE="${XDG_CACHE_HOME:-$HOME/.cache}/video2-vpa/autoscaler"
if [[ ! -d "$VPA_SOURCE/.git" ]]; then
  mkdir -p "$(dirname "$VPA_SOURCE")"
  git clone --depth 1 --branch "vertical-pod-autoscaler-$VPA_VERSION" \
    https://github.com/kubernetes/autoscaler.git "$VPA_SOURCE"
fi
test "$(git -C "$VPA_SOURCE" rev-parse HEAD)" = "$VPA_COMMIT"
VPA_DEPLOY="$VPA_SOURCE/vertical-pod-autoscaler/deploy"
test -z "$(kubectl --context "$SELF_CONTEXT" -n kube-system get deploy \
  vpa-updater vpa-admission-controller --ignore-not-found -o name)"
sed -n '1,80p' "$VPA_DEPLOY/recommender-deployment.yaml"
kubectl --context "$SELF_CONTEXT" apply -f "$VPA_DEPLOY/vpa-v1-crd-gen.yaml"
kubectl --context "$SELF_CONTEXT" apply -f "$VPA_DEPLOY/vpa-rbac.yaml"
kubectl --context "$SELF_CONTEXT" apply -f "$VPA_DEPLOY/recommender-deployment.yaml"
kubectl --context "$SELF_CONTEXT" -n kube-system \
  rollout status deploy/vpa-recommender --timeout=180s
kubectl --context "$SELF_CONTEXT" get crd \
  verticalpodautoscalers.autoscaling.k8s.io
```

Ожидаю: source имеет exact commit, установлены CRD/RBAC/recommender; updater и admission-controller отсутствуют, recommender доступен.

## V2-C3-S11-C02 · Получить рекомендацию VPA без пересоздания Pod'ов

```bash
PODS_BEFORE="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod \
  -l app=devops-may-cry \
  -o jsonpath='{range .items[*]}{.metadata.uid}{"\n"}{end}' | sort | tr '\n' ' ')"
kubectl --context "$SELF_CONTEXT" apply -f vpa_lab.yaml
VPA_TARGET=""
for attempt in $(seq 1 36); do
  VPA_TARGET="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get vpa devops-may-cry \
    -o jsonpath='{.status.recommendation.containerRecommendations[0].target.cpu}{" / "}{.status.recommendation.containerRecommendations[0].target.memory}' \
    2>/dev/null || true)"
  test "$VPA_TARGET" != " / " && test -n "$VPA_TARGET" && break
  printf 'waiting for VPA recommendation (%s/36)\r' "$attempt"
  sleep 10
done
test "$VPA_TARGET" != " / "
printf 'VPA target cpu / memory: %s\n' "$VPA_TARGET"
kubectl --context "$SELF_CONTEXT" -n traffic-lab describe vpa devops-may-cry \
  | sed -n '/Recommendation:/,$p'
PODS_AFTER="$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get pod \
  -l app=devops-may-cry \
  -o jsonpath='{range .items[*]}{.metadata.uid}{"\n"}{end}' | sort | tr '\n' ' ')"
printf 'pod UIDs before: %s\npod UIDs after:  %s\n' "$PODS_BEFORE" "$PODS_AFTER"
test "$PODS_BEFORE" = "$PODS_AFTER"
kubectl --context "$SELF_CONTEXT" -n traffic-lab \
  delete vpa devops-may-cry --ignore-not-found
```

Ожидаю: VPA публикует target CPU/memory; UID двух Pod'ов до и после совпадают, потому что `updateMode: Off`. Объект VPA удалён.

## V2-C3-S12-C01 · Включить Cluster Autoscaler в существующей managed node group

```bash
MANAGED_TF="$REPO_ROOT/infra/managed/terraform"
cd "$MANAGED_TF" || exit
export YC_TOKEN="$(yc iam create-token)"
export YC_CLOUD_ID="$(yc config get cloud-id)"
export YC_FOLDER_ID="$(yc config get folder-id)"
test -n "$YC_TOKEN" && test -n "$YC_CLOUD_ID" && test -n "$YC_FOLDER_ID"
terraform init
terraform validate
terraform plan \
  -var='enable_autoscaling=true' \
  -var='autoscaling_min_nodes=2' \
  -var='autoscaling_max_nodes=5' \
  -out=/tmp/video2-cluster-autoscaler.tfplan \
  >/tmp/video2-cluster-autoscaler-plan.log
terraform show -json /tmp/video2-cluster-autoscaler.tfplan \
  | jq -r '.resource_changes[] | [.address, (.change.actions | join(","))] | @tsv'
terraform apply -no-color /tmp/video2-cluster-autoscaler.tfplan \
  >/tmp/video2-cluster-autoscaler-apply.log
grep -E '^(Apply complete|Outputs:|[[:alnum:]_]+ = <sensitive>)' \
  /tmp/video2-cluster-autoscaler-apply.log
yc managed-kubernetes node-group list --format json \
  | jq -r '.[] | [.name, .status] | @tsv'
kubectl --context "$MANAGED_CONTEXT" get nodes -o wide
BASELINE_NODES="$(kubectl --context "$MANAGED_CONTEXT" get nodes \
  --no-headers | wc -l | tr -d ' ')"
test "$BASELINE_NODES" -eq 2
```

Ожидаю: IAM-токен обновлён в текущем shell; Terraform меняет существующую node group с fixed scale на auto scale `2..5`; перед нагрузкой в managed-кластере ровно две Ready-ноды.

## V2-C3-S12-C02 · Создать 1500m Pending и доказать появление новой ноды

```bash
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/32_3.11_cluster_autoscaler"
cd "$LAB_DIR" || exit
kubectl --context "$MANAGED_CONTEXT" apply -f devops_may_cry.yaml
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab \
  scale deploy/devops-may-cry --replicas=0
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab \
  rollout status deploy/devops-may-cry --timeout=180s
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab patch deploy devops-may-cry \
  --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"1500m"}]'
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab \
  scale deploy/devops-may-cry --replicas=3
PENDING_POD=""
for _attempt in $(seq 1 30); do
  PENDING_POD="$(kubectl --context "$MANAGED_CONTEXT" -n traffic-lab get pod \
    -l app=devops-may-cry --field-selector=status.phase=Pending \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  test -n "$PENDING_POD" && break
  sleep 2
done
test -n "$PENDING_POD"
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab describe pod "$PENDING_POD" \
  | sed -n '/Events:/,$p'
for _attempt in $(seq 1 60); do
  PHASE="$(kubectl --context "$MANAGED_CONTEXT" -n traffic-lab get pod "$PENDING_POD" \
    -o jsonpath='{.status.phase}')"
  CURRENT_NODES="$(kubectl --context "$MANAGED_CONTEXT" get nodes \
    --no-headers | wc -l | tr -d ' ')"
  printf 'nodes=%s pod=%s phase=%s\n' "$CURRENT_NODES" "$PENDING_POD" "$PHASE"
  test "$CURRENT_NODES" -gt "$BASELINE_NODES" && test "$PHASE" = "Running" && break
  sleep 10
done
test "$CURRENT_NODES" -gt "$BASELINE_NODES"
test "$PHASE" = "Running"
kubectl --context "$MANAGED_CONTEXT" get nodes -o wide
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab get pods \
  -l app=devops-may-cry -o wide
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab patch deploy devops-may-cry \
  --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"}]'
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab \
  scale deploy/devops-may-cry --replicas=2
kubectl --context "$MANAGED_CONTEXT" -n traffic-lab \
  rollout status deploy/devops-may-cry --timeout=180s
```

Ожидаю: после контролируемого lab-reset в ноль сразу создаются три реплики с request `1500m`; третья сначала Pending с событием `Insufficient cpu`. Затем число Ready-нод становится больше двух и тот же Pod переходит в Running. В конце request и replicas возвращены к baseline.
