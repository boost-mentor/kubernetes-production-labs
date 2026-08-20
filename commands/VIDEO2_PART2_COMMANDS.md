# VIDEO2 · Часть 2 · команды для записи

Это единственный командник для основной записи части 2. Иди сверху вниз и копируй только блок с ID, который сейчас показан в суфлёре. Все команды прямые: backstage-скриптов в кадре нет.

## V2-C2-S01-C01 · Зафиксировать self-managed context и спросить API о схеме affinity

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
set -a
source recording/.recording.env
set +a
CTX="${SELF_CONTEXT:-kubespray}"
kubectl --context "$CTX" cluster-info
kubectl --context "$CTX" explain pod.spec.affinity
kubectl --context "$CTX" explain pod.spec.affinity.nodeAffinity
kubectl --context "$CTX" explain pod.spec.affinity.podAntiAffinity
```

Ожидаю: отвечает self-managed API; у nodeAffinity и podAntiAffinity видны `requiredDuringSchedulingIgnoredDuringExecution` и `preferredDuringSchedulingIgnoredDuringExecution`.

## V2-C2-S02-C01 · Подготовить выделенную database-ноду и секрет без вывода пароля

```bash
LAB="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/15_2.2_taint_toleration"
kubectl --context "$CTX" create namespace traffic-lab --dry-run=client -o yaml | kubectl --context "$CTX" apply -f -
kubectl --context "$CTX" describe node node1 | sed -n '/Taints:/p'
kubectl --context "$CTX" label node node3 workload.boostmentor.dev/tier=database --overwrite
kubectl --context "$CTX" taint node node3 dedicated=database:NoSchedule
read -r -s -p 'temporary DB password: ' DB_PASSWORD; echo
kubectl --context "$CTX" -n traffic-lab create secret generic devops-may-cry-db \
  --from-literal=POSTGRES_DB=devopsmaycry \
  --from-literal=POSTGRES_USER=devopsmaycry \
  --from-literal=POSTGRES_PASSWORD="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl --context "$CTX" apply -f -
unset DB_PASSWORD
```

Ожидаю: node1 уже защищён control-plane taint; node3 получает label и `dedicated=database:NoSchedule`; Secret создан, пароль в терминал не выведен.

## V2-C2-S02-C02 · Получить Pending без toleration и прочитать Events

```bash
kubectl --context "$CTX" apply -f "$LAB/postgres-pending.yaml"
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry-postgres -o wide
kubectl --context "$CTX" -n traffic-lab describe pod -l app=devops-may-cry-postgres | sed -n '/Events:/,$p'
```

Ожидаю: PostgreSQL остаётся `Pending`; Events одновременно показывают требование nodeAffinity и отсутствие toleration для taint database-ноды.

## V2-C2-S02-C03 · Добавить toleration и запустить реальный PostgreSQL на node3

```bash
kubectl --context "$CTX" -n traffic-lab create configmap devops-may-cry-db-init \
  --from-file=001_init.sql="$LAB/001_init.sql" \
  --dry-run=client -o yaml | kubectl --context "$CTX" apply -f -
kubectl --context "$CTX" apply -f "$LAB/postgres-scheduled.yaml"
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry-postgres --timeout=120s
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry-postgres -o wide
```

Ожидаю: Pod `Running` именно на node3. Это настоящий PostgreSQL, но данные живут в `emptyDir`: для этой scheduler-лабы они намеренно одноразовые.

## V2-C2-S03-C01 · Показать смысл IgnoredDuringExecution

```bash
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry-postgres -o wide
kubectl --context "$CTX" label node node3 workload.boostmentor.dev/tier-
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry-postgres -o wide
```

Ожидаю: уже запущенный PostgreSQL остаётся на node3, хотя label больше не соответствует required nodeAffinity.

## V2-C2-S03-C02 · Пересоздать Pod и вернуть label после доказанного Pending

```bash
OLD_POD="$(kubectl --context "$CTX" -n traffic-lab get pod \
  -l app=devops-may-cry-postgres -o jsonpath='{.items[0].metadata.name}')"
OLD_UID="$(kubectl --context "$CTX" -n traffic-lab get pod "$OLD_POD" \
  -o jsonpath='{.metadata.uid}')"
kubectl --context "$CTX" -n traffic-lab delete pod "$OLD_POD" --wait=true

NEW_POD=""
for _ in $(seq 1 60); do
  NEW_POD="$(kubectl --context "$CTX" -n traffic-lab get pod \
    -l app=devops-may-cry-postgres \
    -o jsonpath='{range .items[*]}{.metadata.uid}{" "}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' \
    | awk -v old="$OLD_UID" '$1 != old && $3 == "Pending" {print $2; exit}')"
  [ -n "$NEW_POD" ] && break
  sleep 1
done
test -n "$NEW_POD"
kubectl --context "$CTX" -n traffic-lab get pod "$NEW_POD" -o wide
kubectl --context "$CTX" -n traffic-lab describe pod "$NEW_POD" | sed -n '/Events:/,$p'
kubectl --context "$CTX" label node node3 workload.boostmentor.dev/tier=database --overwrite
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry-postgres --timeout=120s
kubectl --context "$CTX" -n traffic-lab get pod "$NEW_POD" -o wide
```

Ожидаю: цикл находит именно новый UID в фазе `Pending`; Events показывают невозможную nodeAffinity. После возврата label тот же новый Pod становится `Running`.

## V2-C2-S04-C01 · Вернуть workers в общий пул и разложить DEVOPS MAY CRY мягко

```bash
kubectl --context "$CTX" -n traffic-lab delete deploy/devops-may-cry-postgres svc/devops-may-cry-postgres --ignore-not-found
kubectl --context "$CTX" -n traffic-lab delete secret/devops-may-cry-db configmap/devops-may-cry-db-init --ignore-not-found
kubectl --context "$CTX" taint node node3 dedicated=database:NoSchedule- 2>/dev/null || true
kubectl --context "$CTX" label node node3 workload.boostmentor.dev/tier- 2>/dev/null || true
kubectl --context "$CTX" apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry -o wide
```

Ожидаю: database-демо удалено, taint/label сняты, две реплики приложения `Running` и стараются разойтись по node2/node3.

## V2-C2-S04-C02 · Сделать anti-affinity жёсткой и увидеть цену третьей реплики

```bash
PATCH="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/17_2.4_pod_anti_affinity/required-anti-affinity-patch.yaml"
kubectl --context "$CTX" -n traffic-lab scale deploy devops-may-cry --replicas=0
POD_COUNT=1
for _attempt in $(seq 1 30); do
  POD_COUNT="$(kubectl --context "$CTX" -n traffic-lab get pod \
    -l app=devops-may-cry --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  test "$POD_COUNT" -eq 0 && break
  sleep 2
done
test "$POD_COUNT" -eq 0
kubectl --context "$CTX" -n traffic-lab patch deploy devops-may-cry --type merge --patch-file "$PATCH"
kubectl --context "$CTX" -n traffic-lab scale deploy devops-may-cry --replicas=3
RUNNING=0
PENDING=0
for _attempt in $(seq 1 30); do
  RUNNING="$(kubectl --context "$CTX" -n traffic-lab get pod \
    -l app=devops-may-cry --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  PENDING="$(kubectl --context "$CTX" -n traffic-lab get pod \
    -l app=devops-may-cry --field-selector=status.phase=Pending \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  printf 'running=%s pending=%s\n' "$RUNNING" "$PENDING"
  test "$RUNNING" -eq 2 && test "$PENDING" -eq 1 && break
  sleep 2
done
test "$RUNNING" -eq 2
test "$PENDING" -eq 1
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry -o wide
kubectl --context "$CTX" -n traffic-lab describe pod -l app=devops-may-cry | sed -n '/Events:/,$p'
```

Ожидаю: после контролируемого lab-reset на двух workers работают две новые реплики, третья `Pending`; Events объясняют конфликт required podAntiAffinity.

## V2-C2-S04-C03 · Удалить жёсткое правило и вернуть базовые две реплики

```bash
kubectl --context "$CTX" -n traffic-lab patch deploy devops-may-cry --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/affinity/podAntiAffinity/requiredDuringSchedulingIgnoredDuringExecution"}]'
kubectl --context "$CTX" -n traffic-lab scale deploy devops-may-cry --replicas=2
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
```

Ожидаю: Deployment снова имеет две Ready-реплики; required anti-affinity удалена.

## V2-C2-S05-C01 · Измерить maxSkew на четырёх и пяти репликах

```bash
PATCH="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/18_2.5_topology_spread/hard-spread-patch.yaml"
kubectl --context "$CTX" -n traffic-lab patch deploy devops-may-cry --type merge --patch-file "$PATCH"
kubectl --context "$CTX" -n traffic-lab scale deploy devops-may-cry --replicas=4
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.spec.nodeName
kubectl --context "$CTX" -n traffic-lab scale deploy devops-may-cry --replicas=5
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.spec.nodeName
```

Ожидаю: четыре Pod'а распределены `2+2`, пять — `3+2`; разница по hostname не больше `maxSkew: 1`.

## V2-C2-S05-C02 · Вернуть мягкий spread и две реплики

```bash
kubectl --context "$CTX" -n traffic-lab patch deploy devops-may-cry --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/topologySpreadConstraints/0/whenUnsatisfiable","value":"ScheduleAnyway"}]'
kubectl --context "$CTX" -n traffic-lab scale deploy devops-may-cry --replicas=2
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
```

Ожидаю: приложение снова Ready с двумя репликами; spread стал предпочтением, а не причиной Pending.

## V2-C2-S06-C01 · Показать, как LimitRange подставляет ресурсы

```bash
LAB="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/19_2.6_limitrange_quota"
kubectl --context "$CTX" create namespace team-dev
kubectl --context "$CTX" -n team-dev apply -f "$LAB/limitrange_resourcequota.yaml"
kubectl --context "$CTX" -n team-dev run naked --image=nginx:1.27
kubectl --context "$CTX" -n team-dev get pod naked -o jsonpath='{.spec.containers[0].resources}'; echo
kubectl --context "$CTX" -n team-dev describe quota
```

Ожидаю: у Pod без явных resources появились default requests/limits; ResourceQuota уже считает их в `Used`.

## V2-C2-S06-C02 · Получить отказ API на запрос выше квоты и удалить namespace

```bash
kubectl --context "$CTX" -n team-dev run fat --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"fat","image":"nginx:1.27","resources":{"requests":{"cpu":"64"}}}]}}' || true
kubectl --context "$CTX" -n team-dev get events --sort-by=.lastTimestamp | tail -12
kubectl --context "$CTX" delete namespace team-dev
```

Ожидаю: API отклоняет Pod как превышающий quota/LimitRange; namespace удалён вместе с учебными объектами.

## V2-C2-S07-C01 · Создать три разных Pending и получить три разных диагноза

```bash
kubectl --context "$CTX" create namespace pending-lab --dry-run=client -o yaml | kubectl --context "$CTX" apply -f -
kubectl --context "$CTX" -n pending-lab run stuck-selector --image=nginx:1.27 \
  --overrides='{"spec":{"nodeSelector":{"disktype":"nvme"}}}'
kubectl --context "$CTX" -n pending-lab run stuck-resources --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"stuck-resources","image":"nginx:1.27","resources":{"requests":{"cpu":"64","memory":"200Gi"}}}]}}'
kubectl --context "$CTX" taint node node2 maintenance=true:NoSchedule
kubectl --context "$CTX" taint node node3 maintenance=true:NoSchedule
kubectl --context "$CTX" -n pending-lab run stuck-taint --image=nginx:1.27
kubectl --context "$CTX" -n pending-lab get pods
for pod in stuck-selector stuck-resources stuck-taint; do
  echo "=== $pod"
  kubectl --context "$CTX" -n pending-lab describe pod "$pod" | sed -n '/Events:/,$p'
done
```

Ожидаю: все три Pod'а `Pending`, но Events различаются: node selector, недостаток CPU/RAM и untolerated taint.

## V2-C2-S07-C02 · Обязательно вернуть ноды и удалить triage-namespace

```bash
kubectl --context "$CTX" taint node node2 maintenance=true:NoSchedule-
kubectl --context "$CTX" taint node node3 maintenance=true:NoSchedule-
kubectl --context "$CTX" delete namespace pending-lab
kubectl --context "$CTX" -n traffic-lab get deploy,po -l app=devops-may-cry -o wide
```

Ожидаю: временные taints сняты, pending-lab удалён, DEVOPS MAY CRY остаётся Ready для части 3.
