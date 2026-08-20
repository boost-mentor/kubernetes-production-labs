#!/usr/bin/env bash
# ЧТО ПРОВЕРИТЬ ПОСЛЕ ОБНОВЛЕНИЯ. Запускать после каждой ноды и в конце.
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
SELF_CONTEXT="${SELF_CONTEXT:-kubespray}"
KUBECTL=(kubectl --context "$SELF_CONTEXT")
ok(){ echo "  ✅ $1"; }; fail(){ echo "  ❌ $1"; }
echo "════════ POST-UPGRADE CHECK ════════"

echo "→ Версии по нодам (должны совпадать после полного апгрейда)"
"${KUBECTL[@]}" get nodes -o wide --no-headers | awk '{print "     "$1"\t"$2"\t"$5}'

echo "→ Ни одна нода не осталась cordoned"
CORD=$("${KUBECTL[@]}" get nodes --no-headers | grep -c "SchedulingDisabled" || true)
if [ "$CORD" -eq 0 ]; then
  ok "все ноды принимают поды"
else
  fail "$CORD нод в SchedulingDisabled — сделай uncordon!"
fi

echo "→ Системные поды"
"${KUBECTL[@]}" get pods -n kube-system --no-headers | grep -Ev "Running|Completed" | sed 's/^/     /' || ok "все Running"

echo "→ DNS живой"
if "${KUBECTL[@]}" run dnscheck --rm -i --restart=Never --image=busybox:1.36 --timeout=60s \
  -- nslookup kubernetes.default >/dev/null 2>&1; then
  ok "DNS отвечает"
else
  fail "DNS сломан"
fi

echo "→ Приложения"
"${KUBECTL[@]}" get deploy -A --no-headers 2>/dev/null | awk '$3!=$4 {print "     ⚠️  "$1"/"$2" готово "$4" из "$3}' || true

echo "→ Свежие warning-события"
"${KUBECTL[@]}" get events -A --field-selector type=Warning --no-headers 2>/dev/null | tail -8 | sed 's/^/     /'

echo "→ etcd (на мастере)"
echo "     sudo crictl ps | grep etcd"
echo "     kubectl get --raw='/healthz?verbose' | tail -5"
echo "═══════════════════════════════════"
