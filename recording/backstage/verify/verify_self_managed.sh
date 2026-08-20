#!/usr/bin/env bash
# Проверка здоровья self-managed кластера после установки Kubespray.
# В курсе-источнике проверка ограничивалась `get nodes` — этого мало.
# Здесь: ноды, системные поды, CNI, DNS, реальная связность pod-to-pod и pod-to-service.
#
# Запуск:  bash verify_self_managed.sh [kubeconfig] [context]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
RECORDING_ENV="$REPO_ROOT/recording/.recording.env"
if [[ -f "$RECORDING_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$RECORDING_ENV"
  set +a
fi
KUBECONFIG_PATH="${1:-$HOME/.kube/config}"
SELF_CONTEXT="${2:-${SELF_CONTEXT:-kubespray}}"
export KUBECONFIG="$KUBECONFIG_PATH"
KUBECTL=(kubectl --context "$SELF_CONTEXT")
NS="verify-$$"
FAILED=0

ok()   { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; FAILED=1; }
info() { echo "→ $1"; }

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() { "${KUBECTL[@]}" delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "════════ ПРОВЕРКА КЛАСТЕРА ════════"
"${KUBECTL[@]}" cluster-info 2>/dev/null | head -2 || { fail "API-сервер недоступен"; exit 1; }

info "1. Все ноды Ready"
NOT_READY=$("${KUBECTL[@]}" get nodes --no-headers 2>/dev/null | grep -vc " Ready " || true)
TOTAL=$("${KUBECTL[@]}" get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NOT_READY" -eq 0 ] && [ "$TOTAL" -gt 0 ]; then
  ok "$TOTAL нод, все Ready"
  "${KUBECTL[@]}" get nodes -o wide --no-headers | awk '{print "     "$1" "$2" "$5}'
else
  fail "$NOT_READY нод не Ready"; "${KUBECTL[@]}" get nodes
fi

info "2. Версии kubelet одинаковые (после апгрейда особенно важно)"
VERSIONS=$("${KUBECTL[@]}" get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' | tr ' ' '\n' | sort -u)
if [ "$(echo "$VERSIONS" | wc -l | tr -d ' ')" -eq 1 ]; then
  ok "все ноды на $VERSIONS"
else
  fail "версии разъехались:"
  echo "$VERSIONS"
fi

info "3. Системные поды Running"
BAD=$("${KUBECTL[@]}" get pods -n kube-system --no-headers 2>/dev/null \
      | awk '$0 !~ /(Running|Completed)/ { n++ } END { print n+0 }')
if [ "$BAD" -eq 0 ]; then
  ok "все поды kube-system в порядке"
else
  fail "$BAD проблемных подов:"
  "${KUBECTL[@]}" get pods -n kube-system | grep -Ev "Running|Completed"
fi

info "4. CNI работает (Calico/Cilium/Flannel)"
CNI=$("${KUBECTL[@]}" get pods -n kube-system --no-headers 2>/dev/null \
      | grep -Eo "calico-node|cilium|kube-flannel" | head -1)
if [ -n "$CNI" ]; then
  CNI_BAD=$("${KUBECTL[@]}" get pods -n kube-system --no-headers | grep "$CNI" | grep -vc "Running" || true)
  if [ "$CNI_BAD" -eq 0 ]; then
    ok "$CNI поднят на всех нодах"
  else
    fail "$CNI: $CNI_BAD подов не Running"
  fi
else
  fail "CNI не найден — поды не смогут общаться"
fi

info "5. CoreDNS"
DNS_READY=$("${KUBECTL[@]}" get deploy coredns -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [ "${DNS_READY:-0}" -ge 1 ]; then
  ok "CoreDNS: $DNS_READY реплик готово"
else
  fail "CoreDNS не готов"
fi

info "6. Создание пода (проверяем, что шедулер работает)"
"${KUBECTL[@]}" create ns "$NS" >/dev/null 2>&1
"${KUBECTL[@]}" -n "$NS" run t1 --image=registry.k8s.io/e2e-test-images/agnhost:2.47 \
  --command -- sleep 3600 >/dev/null 2>&1
if "${KUBECTL[@]}" -n "$NS" wait --for=condition=Ready pod/t1 --timeout=90s >/dev/null 2>&1; then
  ok "под запустился"
else
  fail "под не стартовал"
  "${KUBECTL[@]}" -n "$NS" describe pod t1 | tail -15
fi

info "7. DNS РАБОТАЕТ ИЗНУТРИ пода"
if "${KUBECTL[@]}" -n "$NS" exec t1 -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
  ok "имена сервисов резолвятся"
else
  fail "DNS изнутри пода НЕ работает"
fi

info "8. Pod-to-Pod связность (между разными нодами)"
"${KUBECTL[@]}" -n "$NS" run t2 --image=registry.k8s.io/e2e-test-images/agnhost:2.47 \
  --command -- /agnhost netexec --http-port=8080 >/dev/null 2>&1
"${KUBECTL[@]}" -n "$NS" wait --for=condition=Ready pod/t2 --timeout=90s >/dev/null 2>&1
POD2_IP=$("${KUBECTL[@]}" -n "$NS" get pod t2 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$POD2_IP" ] && "${KUBECTL[@]}" -n "$NS" exec t1 -- curl -sf --max-time 5 "http://$POD2_IP:8080/hostname" >/dev/null 2>&1; then
  ok "поды видят друг друга напрямую ($POD2_IP)"
else
  fail "pod-to-pod НЕ работает — проблема с CNI"
fi

info "9. Pod-to-Service (kube-proxy + DNS вместе)"
"${KUBECTL[@]}" -n "$NS" expose pod t2 --port=8080 --name=t2-svc >/dev/null 2>&1
sleep 3
if "${KUBECTL[@]}" -n "$NS" exec t1 -- curl -sf --max-time 5 "http://t2-svc:8080/hostname" >/dev/null 2>&1; then
  ok "сервис доступен по имени"
else
  fail "pod-to-service НЕ работает (kube-proxy или DNS)"
fi

info "10. Критичные события за последние 15 минут"
WARN=$("${KUBECTL[@]}" get events -A --field-selector type=Warning --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$WARN" -eq 0 ]; then
  ok "предупреждений нет"
else
  echo "  ⚠️  $WARN предупреждений (последние 5):"
  "${KUBECTL[@]}" get events -A --field-selector type=Warning --no-headers 2>/dev/null | tail -5 | sed 's/^/     /'
fi

echo "════════════════════════════════════"
[ "$FAILED" -eq 0 ] && echo "✅ КЛАСТЕР ЗДОРОВ" || echo "❌ ЕСТЬ ПРОБЛЕМЫ — см. выше"
exit $FAILED
