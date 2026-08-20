#!/usr/bin/env bash
# ЛАБА 1.9 · MetalLB чинит вечный `<pending>`
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/11_1.9_metallb"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl --context kubespray apply -k ./devops-may-cry-base
kubectl --context kubespray -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context kubespray apply -f ./devops-may-cry-loadbalancer.yaml
kubectl --context kubespray -n traffic-lab get svc devops-may-cry-metallb
# До MetalLB Service остаётся в состоянии <pending>.

test -f "$REPO_ROOT/recording/.recording.env" && source "$REPO_ROOT/recording/.recording.env"
: "${NODE_SUBNET_CIDR:?fill recording/.recording.env}"
: "${METALLB_POOL_START:?fill recording/.recording.env}"
: "${METALLB_POOL_END:?fill recording/.recording.env}"
printf 'node subnet: %s\nreserved pool: %s-%s\n' \
  "$NODE_SUBNET_CIDR" "$METALLB_POOL_START" "$METALLB_POOL_END"

kubectl --context kubespray get nodes -o wide
kubectl --context kubespray -n kube-system get configmap kube-proxy -o yaml | grep -A3 -B3 strictARP
# Пул до REC сверен с IPAM/DHCP облака. ping не доказывает, что IP свободен.

helm repo add metallb https://metallb.github.io/metallb
helm repo update metallb
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system --create-namespace \
  --version 0.16.1 --wait --timeout 5m

METALLB_CONFIG="$(mktemp "${TMPDIR:-/tmp}/video2-metallb.XXXXXX.yaml")"
sed -e "s/__POOL_START__/$METALLB_POOL_START/g" \
    -e "s/__POOL_END__/$METALLB_POOL_END/g" \
    "$LAB_DIR/metallb-demo.yaml" > "$METALLB_CONFIG"
cat "$METALLB_CONFIG"
kubectl --context kubespray apply -f "$METALLB_CONFIG"

kubectl --context kubespray -n metallb-system get pods -o wide
kubectl --context kubespray -n metallb-system get ipaddresspool,l2advertisement -o wide
kubectl --context kubespray -n traffic-lab wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' \
  service/devops-may-cry-metallb --timeout=120s
kubectl --context kubespray -n traffic-lab get svc devops-may-cry-metallb -o wide
kubectl --context kubespray -n traffic-lab describe svc devops-may-cry-metallb
kubectl --context kubespray -n metallb-system logs -l component=speaker --tail=40

METALLB_IP="$(kubectl --context kubespray -n traffic-lab get service devops-may-cry-metallb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
INV="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
source "$REPO_ROOT/kubespray/.venv/bin/activate"
ansible -i "$INV" node1 --private-key "$SSH_KEY" -m ansible.builtin.shell \
  -a "ip neigh show $METALLB_IP; curl --max-time 5 -sv http://$METALLB_IP/readyz"
# Если cloud VPC фильтрует L2/ARP, EXTERNAL-IP будет назначен, но curl не пройдёт.
# Это граница сетевой модели: назначенный EXTERNAL-IP ещё не доказывает внешний маршрут.

sed -n '1,220p' ./metallb-bgp-reference.yaml
# BGP reference не применяем: без настоящего router peer это был бы театр.
rm -f "$METALLB_CONFIG"
