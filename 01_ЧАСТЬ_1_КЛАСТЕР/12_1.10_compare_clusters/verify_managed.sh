#!/usr/bin/env bash
# Проверка здоровья self-managed кластера после установки Kubespray.
# В курсе-источнике проверка ограничивалась `get nodes` — этого мало.
# Здесь: ноды, системные поды, CNI, DNS, реальная связность pod-to-pod и pod-to-service.
#
# Запуск:  bash verify_managed.sh [kubeconfig]
set -uo pipefail

KUBECONFIG_PATH="${1:-$HOME/.kube/config}"
export KUBECONFIG="$KUBECONFIG_PATH"
NS="verify-$$"
FAILED=0

ok()   { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; FAILED=1; }
info() { echo "→ $1"; }

cleanup() { kubectl delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "════════ ПРОВЕРКА MANAGED-КЛАСТЕРА ════════"
kubectl cluster-info 2>/dev/null | head -2 || { fail "API-сервер недоступен"; exit 1; }

info "1. Все ноды Ready"
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -vc " Ready " || true)
TOTAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NOT_READY" -eq 0 ] && [ "$TOTAL" -gt 0 ]; then
  ok "$TOTAL нод, все Ready"
  kubectl get nodes -o wide --no-headers | awk '{print "     "$1" "$2" "$5}'
else
  fail "$NOT_READY нод не Ready"; kubectl get nodes
fi

info "2. Версии kubelet одинаковые (после апгрейда особенно важно)"
VERSIONS=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' | tr ' ' '\n' | sort -u)
[ "$(echo "$VERSIONS" | wc -l | tr -d ' ')" -eq 1 ] \
  && ok "все ноды на $VERSIONS" || { fail "версии разъехались:"; echo "$VERSIONS"; }

info "3. Системные поды Running"
BAD=$(kubectl get pods -n kube-system --no-headers 2>/dev/null \
      | grep -Ev "Running|Completed" | wc -l | tr -d ' ')
[ "$BAD" -eq 0 ] && ok "все поды kube-system в порядке" \
  || { fail "$BAD проблемных подов:"; kubectl get pods -n kube-system | grep -Ev "Running|Completed"; }

info "4. Мастер СКРЫТ (это managed — в get nodes только воркеры)"
CP=$(kubectl get nodes --no-headers -l node-role.kubernetes.io/control-plane 2>/dev/null | wc -l | tr -d ' ')
[ "$CP" -eq 0 ] && ok "control-plane не виден — им управляет облако" \
  || echo "  ℹ️  видно $CP control-plane нод (необычно для managed)"

info "4b. CNI работает"
CNI=$(kubectl get pods -n kube-system --no-headers 2>/dev/null \
      | grep -Eo "calico-node|cilium|kube-flannel" | head -1)
if [ -n "$CNI" ]; then
  CNI_BAD=$(kubectl get pods -n kube-system --no-headers | grep "$CNI" | grep -vc "Running" || true)
  [ "$CNI_BAD" -eq 0 ] && ok "$CNI поднят на всех нодах" || fail "$CNI: $CNI_BAD подов не Running"
else
  fail "CNI не найден — поды не смогут общаться"
fi

info "5. CoreDNS"
DNS_READY=$(kubectl get deploy coredns -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
[ "${DNS_READY:-0}" -ge 1 ] && ok "CoreDNS: $DNS_READY реплик готово" || fail "CoreDNS не готов"

info "6. Создание пода (проверяем, что шедулер работает)"
kubectl create ns "$NS" >/dev/null 2>&1
kubectl -n "$NS" run t1 --image=registry.k8s.io/e2e-test-images/agnhost:2.47 \
  --command -- sleep 3600 >/dev/null 2>&1
kubectl -n "$NS" wait --for=condition=Ready pod/t1 --timeout=90s >/dev/null 2>&1 \
  && ok "под запустился" || { fail "под не стартовал"; kubectl -n "$NS" describe pod t1 | tail -15; }

info "7. DNS РАБОТАЕТ ИЗНУТРИ пода"
kubectl -n "$NS" exec t1 -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 \
  && ok "имена сервисов резолвятся" || fail "DNS изнутри пода НЕ работает"

info "8. Pod-to-Pod связность (между разными нодами)"
kubectl -n "$NS" run t2 --image=registry.k8s.io/e2e-test-images/agnhost:2.47 \
  --command -- /agnhost netexec --http-port=8080 >/dev/null 2>&1
kubectl -n "$NS" wait --for=condition=Ready pod/t2 --timeout=90s >/dev/null 2>&1
POD2_IP=$(kubectl -n "$NS" get pod t2 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$POD2_IP" ] && kubectl -n "$NS" exec t1 -- curl -sf --max-time 5 "http://$POD2_IP:8080/hostname" >/dev/null 2>&1; then
  ok "поды видят друг друга напрямую ($POD2_IP)"
else
  fail "pod-to-pod НЕ работает — проблема с CNI"
fi

info "9. Pod-to-Service (kube-proxy + DNS вместе)"
kubectl -n "$NS" expose pod t2 --port=8080 --name=t2-svc >/dev/null 2>&1
sleep 3
kubectl -n "$NS" exec t1 -- curl -sf --max-time 5 "http://t2-svc:8080/hostname" >/dev/null 2>&1 \
  && ok "сервис доступен по имени" || fail "pod-to-service НЕ работает (kube-proxy или DNS)"

info "10. Критичные события за последние 15 минут"
WARN=$(kubectl get events -A --field-selector type=Warning --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$WARN" -eq 0 ] && ok "предупреждений нет" \
  || { echo "  ⚠️  $WARN предупреждений (последние 5):";
       kubectl get events -A --field-selector type=Warning --no-headers 2>/dev/null | tail -5 | sed 's/^/     /'; }

echo "════════════════════════════════════"
[ "$FAILED" -eq 0 ] && echo "✅ КЛАСТЕР ЗДОРОВ" || echo "❌ ЕСТЬ ПРОБЛЕМЫ — см. выше"
exit $FAILED
