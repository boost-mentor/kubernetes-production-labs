#!/usr/bin/env bash
# ЛАБА 4.10 · «Трафик не идёт»: чеклист на сломанном сервисе
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: night-shift-broken
  namespace: traffic-lab
spec:
  selector:
    app: nigth-shift   # ← опечатка в лейбле: такого нет НИ У КОГО (nigth ≠ night)
  ports:
    - port: 80
      targetPort: 8080
EOF


CLUSTER_IP=$(kubectl -n traffic-lab get svc night-shift-broken -o jsonpath='{.spec.clusterIP}')
read -r -p "floating/public IP Kubernetes-ноды для SSH: " NODE_SSH_HOST
ssh "ubuntu@$NODE_SSH_HOST" "sudo conntrack -L 2>/dev/null | grep '$CLUSTER_IP' | head -3"
# → tcp 6 … src=10.233.х.х dst=<ClusterIP> … dport=80  [reply] src=<IP пода> dport=8080


# 1. Симптом:
kubectl -n traffic-lab exec client -- curl -m3 -s -o /dev/null -w '%{http_code}\n' night-shift-broken
# → 000 / timeout — «не работает»
# 2. DNS виноват?
kubectl -n traffic-lab exec client -- dig +short night-shift-broken     # → ClusterIP есть! DNS чист
# 3. Есть ли у сервиса бэкенды? ← ключевой шаг
kubectl -n traffic-lab get endpointslice -l kubernetes.io/service-name=night-shift-broken
# → endpoints ПУСТО. Вот и диагноз: сервис никого не выбрал
# 4. Кого он ИЩЕТ и кто ЕСТЬ на самом деле:
kubectl -n traffic-lab describe svc night-shift-broken | grep Selector   # → app=nigth-shift
kubectl -n traffic-lab get pods --show-labels                    # → у подов app=night-shift
# 5. Чиним и проверяем:
kubectl -n traffic-lab patch svc night-shift-broken -p '{"spec":{"selector":{"app":"night-shift"}}}'
kubectl -n traffic-lab get endpointslice -l kubernetes.io/service-name=night-shift-broken   # → 2 endpoints
kubectl -n traffic-lab exec client -- curl -s -o /dev/null -w '%{http_code}\n' night-shift-broken   # → 200


kubectl delete namespace traffic-lab
sudo sed -i '' '/myapp.local/d' /etc/hosts 2>/dev/null   # если осталось от 4.3
