#!/usr/bin/env bash
# ЧТО ПРОВЕРИТЬ ПОСЛЕ ОБНОВЛЕНИЯ. Запускать после каждой ноды и в конце.
set -uo pipefail
ok(){ echo "  ✅ $1"; }; fail(){ echo "  ❌ $1"; }
echo "════════ POST-UPGRADE CHECK ════════"

echo "→ Версии по нодам (должны совпадать после полного апгрейда)"
kubectl get nodes -o wide --no-headers | awk '{print "     "$1"\t"$2"\t"$5}'

echo "→ Ни одна нода не осталась cordoned"
CORD=$(kubectl get nodes --no-headers | grep -c "SchedulingDisabled" || true)
[ "$CORD" -eq 0 ] && ok "все ноды принимают поды" || fail "$CORD нод в SchedulingDisabled — сделай uncordon!"

echo "→ Системные поды"
kubectl get pods -n kube-system --no-headers | grep -Ev "Running|Completed" | sed 's/^/     /' || ok "все Running"

echo "→ DNS живой"
kubectl run dnscheck --rm -i --restart=Never --image=busybox:1.36 --timeout=60s \
  -- nslookup kubernetes.default >/dev/null 2>&1 && ok "DNS отвечает" || fail "DNS сломан"

echo "→ Приложения"
kubectl get deploy -A --no-headers 2>/dev/null | awk '$3!=$4 {print "     ⚠️  "$1"/"$2" готово "$4" из "$3}' || true

echo "→ Свежие warning-события"
kubectl get events -A --field-selector type=Warning --no-headers 2>/dev/null | tail -8 | sed 's/^/     /'

echo "→ etcd (на мастере)"
echo "     sudo crictl ps | grep etcd"
echo "     kubectl get --raw='/healthz?verbose' | tail -5"
echo "═══════════════════════════════════"
