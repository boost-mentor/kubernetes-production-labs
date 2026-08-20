#!/usr/bin/env bash
# ЧТО ПРОВЕРИТЬ ПЕРЕД ОБНОВЛЕНИЕМ КЛАСТЕРА. Запускать до upgrade-cluster.yml.
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
FAILED=0
ok(){ echo "  ✅ $1"; }; fail(){ echo "  ❌ $1"; FAILED=1; }; warn(){ echo "  ⚠️  $1"; }

echo "════════ PRE-UPGRADE CHECK ════════"

echo "→ 1. Текущие версии"
"${KUBECTL[@]}" get nodes -o custom-columns='NODE:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,OS:.status.nodeInfo.osImage' --no-headers | sed 's/^/     /'
CUR=$("${KUBECTL[@]}" version -o json 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['serverVersion']['gitVersion'])" 2>/dev/null || echo "?")
echo "     API-сервер: $CUR"
warn "Прыгать можно ТОЛЬКО на +1 минорную версию. 1.34 → 1.35 ✓, 1.34 → 1.36 ✗"

echo "→ 2. Все ноды Ready (нельзя обновлять сломанный кластер)"
NR=$("${KUBECTL[@]}" get nodes --no-headers | grep -vc " Ready " || true)
if [ "$NR" -eq 0 ]; then
  ok "все ноды Ready"
else
  fail "$NR нод не Ready — сначала почини"
fi

echo "→ 3. Системные поды здоровы"
BAD=$("${KUBECTL[@]}" get pods -n kube-system --no-headers | awk '$0 !~ /(Running|Completed)/ { n++ } END { print n+0 }')
if [ "$BAD" -eq 0 ]; then
  ok "kube-system в порядке"
else
  fail "$BAD проблемных подов"
fi

echo "→ 4. PodDisruptionBudget — могут заблокировать drain"
PDB=$("${KUBECTL[@]}" get pdb -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$PDB" -gt 0 ]; then
  warn "$PDB PDB в кластере. Проверь ALLOWED DISRUPTIONS — если 0, drain повиснет:"
  "${KUBECTL[@]}" get pdb -A | sed 's/^/     /'
else
  ok "PDB нет — drain не заблокируется"
fi

echo "→ 5. Одиночные реплики (их выселение = простой сервиса)"
SINGLE=$("${KUBECTL[@]}" get deploy -A --no-headers 2>/dev/null | awk '$3==1 {print "     "$1"/"$2}' | head -10)
if [ -n "$SINGLE" ]; then
  warn "деплойменты с 1 репликой — при drain лягут:"
  echo "$SINGLE"
else
  ok "одиночных реплик нет"
fi

echo "→ 6. Запас ресурсов (подам с выселяемой ноды нужно куда-то переехать)"
"${KUBECTL[@]}" top nodes 2>/dev/null | sed 's/^/     /' || warn "metrics-server не установлен, запас не проверить"

echo "→ 7. Срок сертификатов control-plane"
echo "     Выполнить НА МАСТЕРЕ: sudo kubeadm certs check-expiration"
warn "Если серты протухли — обновление упадёт. Классика 'кластер умер через год'"

echo "→ 8. Бэкап etcd — ОБЯЗАТЕЛЬНО перед апгрейдом"
echo "     На мастере:"
echo "     sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \\"
echo "       --cacert=/etc/ssl/etcd/ssl/ca.pem \\"
echo "       --cert=/etc/ssl/etcd/ssl/admin-\$(hostname).pem \\"
echo "       --key=/etc/ssl/etcd/ssl/admin-\$(hostname)-key.pem \\"
echo "       snapshot save /root/etcd-backup-\$(date +%F).db"
warn "Snapshot не считается бэкапом, пока не проверены status и отдельный restore-runbook"

echo "→ 9. Сохранить inventory, group_vars и kubeconfig"
warn "cp -r inventory/mycluster ~/backup-inventory-\$(date +%F)"

echo "→ 10. Deprecated API в манифестах"
echo "     Проверяй целевую minor-версию по официальному deprecation guide и release notes."
echo "     Перед каждым upgrade: pluto detect-all-in-cluster + scan GitOps-репозитория."
warn "Сегодняшняя проверка не заменяет повторный аудит перед следующим minor upgrade"

echo "═══════════════════════════════════"
[ "$FAILED" -eq 0 ] && echo "✅ МОЖНО ОБНОВЛЯТЬ" || echo "❌ СНАЧАЛА ПОЧИНИ ПРОБЛЕМЫ ВЫШЕ"
exit $FAILED
