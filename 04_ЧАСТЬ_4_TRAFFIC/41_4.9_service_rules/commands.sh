#!/usr/bin/env bash
# ЛАБА 4.9 · ClusterIP → EndpointSlice → kube-proxy IPVS → Pod: сверяем все четыре слоя
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/41_4.9_service_rules"
cd "$LAB_DIR" || exit

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./devops_may_cry.yaml
kubectl -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl apply -f ./service-client.yaml
kubectl -n traffic-lab wait --for=condition=Ready pod/service-proof-client --timeout=180s

# Слой 1: Service хранит VIP и selector, но не список backend-адресов.
kubectl -n traffic-lab get svc devops-may-cry -o wide
kubectl -n traffic-lab get svc devops-may-cry \
  -o jsonpath='clusterIP={.spec.clusterIP}{" selector="}{.spec.selector}{" port="}{.spec.ports[0].port}{" -> targetPort="}{.spec.ports[0].targetPort}{"\n"}'
SERVICE_IP="$(kubectl -n traffic-lab get svc devops-may-cry \
  -o jsonpath='{.spec.clusterIP}')"

# Слой 2: EndpointSlice — фактические ready Pod IP и target port.
kubectl -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry -o wide
kubectl -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry \
  -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{" node="}{.nodeName}{"\n"}{end}'

# Слой 3: проверяем режим kube-proxy и сами IPVS-правила на worker-нодах.
kubectl -n kube-system get configmap kube-proxy \
  -o jsonpath='{.data.config\.conf}' | grep -E '^mode:|^strictARP:'
ANSIBLE="$REPO_ROOT/.venv/bin/ansible"
INVENTORY="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
test -x "$ANSIBLE"
test -f "$INVENTORY"
"$ANSIBLE" -i "$INVENTORY" kube_node --become -m shell \
  -a "ip -brief address show kube-ipvs0; ipvsadm -Ln | grep -F -A4 '${SERVICE_IP}:80'"

# Слой 4: проходим через DNS-имя Service и получаем HTTP 200 от ready Pod.
kubectl -n traffic-lab exec service-proof-client -- \
  curl -fsS -o /dev/null -w 'service HTTP %{http_code}\n' \
  http://devops-may-cry/readyz

# Сломанная гипотеза: ClusterIP — не «IP приложения». В IPVS-режиме kube-proxy
# помещает VIP на kube-ipvs0 и ведёт virtual-server с backend из EndpointSlice.
# В nftables/iptables-режиме доказательство будет другим; эта лаба намеренно pinned на IPVS.

# Restore только debug-client; боевой workload остаётся для следующей сетевой сцены.
kubectl -n traffic-lab delete pod service-proof-client --ignore-not-found
