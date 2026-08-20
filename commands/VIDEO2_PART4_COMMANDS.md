# VIDEO2 · Часть 4 · команды для записи

Командник идёт по фактическому пути запроса. Копируй только блок с ID из суфлёра. Команды прямые; backstage-helpers нужны лишь для сброса между дублями.

## V2-C4-S01-C01 · Увидеть TCP handshake на loopback

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
sudo -v
sudo tcpdump -i lo0 -n 'tcp port 8080' &
TCPDUMP_PID=$!
python3 -m http.server 8080 >/tmp/video2-http.log 2>&1 &
HTTP_PID=$!
sleep 1
curl -fsS http://127.0.0.1:8080/ >/dev/null
sleep 1
sudo kill -INT "$TCPDUMP_PID" 2>/dev/null || true
wait "$TCPDUMP_PID" || true
netstat -an | grep -E 'LISTEN|ESTABLISHED|TIME_WAIT' | head
kill "$HTTP_PID" 2>/dev/null || true
```

Ожидаю: в tcpdump видны SYN → SYN/ACK → ACK, затем HTTP-пакеты и закрытие соединения; `netstat` показывает состояния TCP.

## V2-C4-S02-C01 · Доказать, что Basic base64 читается из трафика

```bash
python3 -m http.server 8080 >/tmp/video2-http.log 2>&1 &
HTTP_PID=$!
sleep 1
sudo -v
sudo tcpdump -i lo0 -n -A 'tcp port 8080' &
TCPDUMP_PID=$!
sleep 1
curl -s http://127.0.0.1:8080/secret -H 'Authorization: Basic dXNlcjpwYXNz' >/dev/null
sleep 1
sudo kill -INT "$TCPDUMP_PID" 2>/dev/null || true
wait "$TCPDUMP_PID" || true
printf 'dXNlcjpwYXNz' | base64 -d; echo
kill "$HTTP_PID" 2>/dev/null || true
```

Ожидаю: ASCII capture содержит HTTP-заголовок Authorization; base64 декодируется в `user:pass`. Это кодирование, не шифрование.

## V2-C4-S03-C01 · Сравнить системный resolver и прямой DNS-запрос

```bash
cat /etc/hosts
scutil --dns | sed -n '1,90p'
dig example.com A
dig +trace example.com A
echo '127.0.0.1 myapp.local' | sudo tee -a /etc/hosts
ping -c1 myapp.local
dig myapp.local +short
sudo sed -i '' '/myapp.local/d' /etc/hosts
```

Ожидаю: системный resolver находит `myapp.local` через hosts, а `dig` обращается прямо к DNS и ничего о hosts не знает; строка после доказательства удалена.

## V2-C4-S04-C01 · Снять DNS-пакеты через фактический resolver без изменения VPN

```bash
DNS_SERVER="$(scutil --dns | awk '/nameserver\[[0-9]+\]/{print $3; exit}')"
test -n "$DNS_SERVER"
IFACE="$(route -n get "$DNS_SERVER" | awk '/interface:/{print $2; exit}')"
printf 'resolver=%s interface=%s\n' "$DNS_SERVER" "$IFACE"
sudo -v
sudo tcpdump -i "$IFACE" -n "host $DNS_SERVER and port 53" &
TCPDUMP_PID=$!
sleep 1
dig @"$DNS_SERVER" example.com A
sleep 1
sudo kill -INT "$TCPDUMP_PID" 2>/dev/null || true
wait "$TCPDUMP_PID" || true
```

Ожидаю: запрос и ответ DNS видны на интерфейсе реального route. VPN, DNS и системные routes не меняются.

## V2-C4-S05-C01 · Проследить route с ноутбука и private route между VM

```bash
set -a
source "$REPO_ROOT/recording/.recording.env"
set +a
SSH_KEY="${VIDEO2_SSH_KEY:?fill VIDEO2_SSH_KEY in recording/.recording.env}"
SSH_USER="${VIDEO2_SSH_USER:-root}"
NODE1_PUBLIC_IP="${NODE1_SSH_HOST:?fill NODE1_SSH_HOST}"
NODE2_PUBLIC_IP="${NODE2_SSH_HOST:?fill NODE2_SSH_HOST}"
NODE3_PRIVATE_IP="$(ssh -i "$SSH_KEY" "$SSH_USER@${NODE3_SSH_HOST:?fill NODE3_SSH_HOST}" \
  "ip -4 route get 1.1.1.1 | awk '{for (i=1;i<=NF;i++) if (\$i==\"src\") {print \$(i+1); exit}}'")"
route -n get default
route -n get "$NODE1_PUBLIC_IP"
traceroute -m 5 "$NODE1_PUBLIC_IP" || true
ssh -i "$SSH_KEY" "$SSH_USER@$NODE2_PUBLIC_IP" \
  "ip -4 route; ip route get '$NODE3_PRIVATE_IP'"
```

Ожидаю: ноутбук выбирает interface/gateway по таблице маршрутов; node2 достигает private IP node3 по VPC route. Никакой маршрут вручную не добавляется.

## V2-C4-S06-C01 · Запустить приложение и debug-client, затем открыть Pod resolv.conf

```bash
set -a
source "$REPO_ROOT/recording/.recording.env"
set +a
CTX="${SELF_CONTEXT:-kubespray}"
LAB="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/38_4.6_pod_resolv_coredns"
kubectl --context "$CTX" apply -f "$LAB/devops_may_cry.yaml"
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context "$CTX" apply -f "$LAB/debug-client.yaml"
kubectl --context "$CTX" -n traffic-lab wait --for=condition=Ready pod/client --timeout=180s
kubectl --context "$CTX" -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl --context "$CTX" -n traffic-lab exec client -- cat /etc/resolv.conf
```

Ожидаю: CoreDNS Pod'ы Running; в client видны cluster DNS Service IP, search suffixes и `options ndots:5`.

## V2-C4-S06-C02 · Разрешить полное и короткое имя Service через CoreDNS

```bash
kubectl --context "$CTX" -n traffic-lab exec client -- \
  dig +short devops-may-cry.traffic-lab.svc.cluster.local
kubectl --context "$CTX" -n traffic-lab exec client -- \
  dig +search +short devops-may-cry
```

Ожидаю: оба запроса возвращают один ClusterIP; короткое имя раскрывается через search текущего namespace.

## V2-C4-S07-C01 · Открыть NodePort и проверить вход через Kubernetes-ноду

```bash
kubectl --context "$CTX" apply -f "$REPO_ROOT/kubernetes/devops-may-cry/services/nodeport.yaml"
kubectl --context "$CTX" -n traffic-lab get service devops-may-cry-ha-nodeport -o wide
NODE_PORT="$(kubectl --context "$CTX" -n traffic-lab get svc devops-may-cry-ha-nodeport -o jsonpath='{.spec.ports[0].nodePort}')"
NODE2_PRIVATE_IP="$(ssh -i "$SSH_KEY" "$SSH_USER@${NODE2_SSH_HOST:?fill NODE2_SSH_HOST}" \
  "ip -4 route get 1.1.1.1 | awk '{for (i=1;i<=NF;i++) if (\$i==\"src\") {print \$(i+1); exit}}'")"
ssh -i "$SSH_KEY" "$SSH_USER@${LB1_SSH_HOST:?fill LB1_SSH_HOST}" \
  "curl -fsS http://$NODE2_PRIVATE_IP:$NODE_PORT/readyz"
```

Ожидаю: Service показывает NodePort `30080`; запрос с lb1 на private IP node2 получает readiness JSON. Public/floating IP нужен только SSH-клиенту.

## V2-C4-S08-C01 · Связать стабильный ClusterIP с изменяемыми EndpointSlice

```bash
kubectl --context "$CTX" -n traffic-lab get svc devops-may-cry -o wide
kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry -o wide
kubectl --context "$CTX" -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry -o wide
kubectl --context "$CTX" -n traffic-lab exec client -- curl -fsS http://devops-may-cry/readyz
```

Ожидаю: ClusterIP отличается от Pod IP; EndpointSlice содержит ready Pod IP; запрос через имя Service получает HTTP 200.

## V2-C4-S08-C02 · Удалить Pod и увидеть замену endpoint без смены ClusterIP

```bash
SERVICE_IP="$(kubectl --context "$CTX" -n traffic-lab get svc devops-may-cry -o jsonpath='{.spec.clusterIP}')"
POD="$(kubectl --context "$CTX" -n traffic-lab get pod -l app=devops-may-cry -o jsonpath='{.items[0].metadata.name}')"
OLD_POD_IP="$(kubectl --context "$CTX" -n traffic-lab get pod "$POD" -o jsonpath='{.status.podIP}')"
DESIRED="$(kubectl --context "$CTX" -n traffic-lab get deploy devops-may-cry -o jsonpath='{.spec.replicas}')"
kubectl --context "$CTX" -n traffic-lab delete pod "$POD" --wait=true

ENDPOINT_IPS=""
for _ in $(seq 1 180); do
  READY="$(kubectl --context "$CTX" -n traffic-lab get deploy devops-may-cry \
    -o jsonpath='{.status.readyReplicas}')"
  ENDPOINT_IPS="$(kubectl --context "$CTX" -n traffic-lab get endpointslice \
    -l kubernetes.io/service-name=devops-may-cry \
    -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}')"
  ENDPOINT_COUNT="$(printf '%s\n' "$ENDPOINT_IPS" | awk 'NF {n++} END {print n+0}')"
  if [ "${READY:-0}" = "$DESIRED" ] \
    && [ "$ENDPOINT_COUNT" -ge "$DESIRED" ] \
    && ! printf '%s\n' "$ENDPOINT_IPS" | grep -Fxq "$OLD_POD_IP"; then
    break
  fi
  sleep 1
done
test "${READY:-0}" = "$DESIRED"
test "$ENDPOINT_COUNT" -ge "$DESIRED"
! printf '%s\n' "$ENDPOINT_IPS" | grep -Fxq "$OLD_POD_IP"
kubectl --context "$CTX" -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry -o wide
test "$SERVICE_IP" = "$(kubectl --context "$CTX" -n traffic-lab get svc devops-may-cry -o jsonpath='{.spec.clusterIP}')"
kubectl --context "$CTX" -n traffic-lab exec client -- curl -fsS http://devops-may-cry/readyz
```

Ожидаю: bounded-цикл ждёт полного числа ready endpoints, старый Pod IP исчезает, а HTTP снова даёт 200; ClusterIP остаётся тем же.

## V2-C4-S09-C01 · Доказать текущий kube-proxy data plane через IPVS

```bash
SERVICE_IP="$(kubectl --context "$CTX" -n traffic-lab get svc devops-may-cry -o jsonpath='{.spec.clusterIP}')"
kubectl --context "$CTX" -n kube-system get configmap kube-proxy \
  -o jsonpath='{.data.config\.conf}' | grep -E '^mode:|^strictARP:'
ANSIBLE="$REPO_ROOT/kubespray/.venv/bin/ansible"
INV="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
"$ANSIBLE" -i "$INV" kube_node --private-key "$SSH_KEY" --become \
  -m ansible.builtin.shell \
  -a "ip -brief address show kube-ipvs0; ipvsadm -Ln | grep -F -A4 '${SERVICE_IP}:80'"
kubectl --context "$CTX" -n traffic-lab exec client -- \
  curl -fsS -o /dev/null -w 'service HTTP %{http_code}\n' http://devops-may-cry/readyz
```

Ожидаю: config сообщает IPVS; на workers VIP находится на `kube-ipvs0`, virtual server указывает на ready endpoints, HTTP возвращает 200.

## V2-C4-S10-C01 · Получить Service с DNS и ClusterIP, но без endpoints

```bash
cat <<'EOF' | kubectl --context "$CTX" apply -f -
apiVersion: v1
kind: Service
metadata:
  name: devops-may-cry-broken
  namespace: traffic-lab
spec:
  selector:
    app: nigth-shift
  ports:
    - port: 80
      targetPort: 8080
EOF
kubectl --context "$CTX" -n traffic-lab exec client -- dig +search +short devops-may-cry-broken
kubectl --context "$CTX" -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry-broken -o wide
kubectl --context "$CTX" -n traffic-lab exec client -- \
  curl -m3 -s -o /dev/null -w '%{http_code}\n' devops-may-cry-broken || true
```

Ожидаю: DNS и ClusterIP существуют, EndpointSlice не содержит ready адресов, HTTP не проходит. Go-приложение при этом остаётся Ready.

## V2-C4-S10-C02 · Найти опечатку selector, восстановить endpoints и HTTP

```bash
kubectl --context "$CTX" -n traffic-lab describe svc devops-may-cry-broken | sed -n '/Selector:/p'
kubectl --context "$CTX" -n traffic-lab get pods --show-labels
kubectl --context "$CTX" -n traffic-lab patch svc devops-may-cry-broken \
  -p '{"spec":{"selector":{"app":"devops-may-cry"}}}'
READY_ENDPOINTS=0
for _attempt in $(seq 1 30); do
  READY_ENDPOINTS="$(kubectl --context "$CTX" -n traffic-lab get endpointslice \
    -l kubernetes.io/service-name=devops-may-cry-broken \
    -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" "}{.conditions.ready}{"\n"}{end}' \
    | grep -c ' true$' || true)"
  test "$READY_ENDPOINTS" -gt 0 && break
  sleep 2
done
test "$READY_ENDPOINTS" -gt 0
kubectl --context "$CTX" -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry-broken -o wide
HTTP_CODE=000
for _attempt in $(seq 1 30); do
  HTTP_CODE="$(kubectl --context "$CTX" -n traffic-lab exec client -- \
    curl -sS -o /dev/null -w '%{http_code}' devops-may-cry-broken/readyz || true)"
  printf 'ready_endpoints=%s http=%s\n' "$READY_ENDPOINTS" "$HTTP_CODE"
  test "$HTTP_CODE" = "200" && break
  sleep 2
done
test "$HTTP_CODE" = "200"
kubectl --context "$CTX" -n traffic-lab delete svc devops-may-cry-broken
```

Ожидаю: selector `nigth-shift` не совпадает с label; после исправления endpoints появляются и HTTP становится 200; сломанный Service удалён.

## V2-C4-S11-C01 · Убрать MetalLB и подготовить NodePort для внешней HA-пары

```bash
set -a
source "$REPO_ROOT/recording/.recording.env"
set +a
CTX="${SELF_CONTEXT:-kubespray}"
HA_DIR="$REPO_ROOT/ansible/external-ha"
INV="$HA_DIR/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:?fill VIDEO2_SSH_KEY in recording/.recording.env}"
source "$REPO_ROOT/kubespray/.venv/bin/activate"
kubectl --context "$CTX" -n traffic-lab delete service devops-may-cry-metallb --ignore-not-found
helm --kube-context "$CTX" uninstall metallb -n metallb-system || true
kubectl --context "$CTX" apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context "$CTX" -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context "$CTX" apply -f "$REPO_ROOT/kubernetes/devops-may-cry/services/nodeport.yaml"
kubectl --context "$CTX" -n traffic-lab get service devops-may-cry-ha-nodeport -o wide
kubectl --context "$CTX" -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry-ha-nodeport -o wide
```

Ожидаю: MetalLB Service/chart удалены, приложение Ready, канонический backend — NodePort 30080 с ready endpoints.

## V2-C4-S11-C02 · Проверить inventory, private IP и backend до применения HA

```bash
sed -n '1,180p' "$HA_DIR/inventory.example.ini"
ansible-inventory -i "$INV" --graph
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.ping
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.setup \
  -a 'filter=ansible_default_ipv4'
ansible-playbook -i "$INV" "$HA_DIR/preflight-backends.yml" --private-key "$SSH_KEY"
```

Ожидаю: безопасный example и graph показывают lb1/lb2 и node1-node3 без hostvars; реальные floating-адреса не печатаются. Hosts доступны, facts показывают private IP для VXLAN/backends; preflight с LB достигает private NodePort всех Kubernetes-нод.

## V2-C4-S11-C03 · Прочитать роли и идемпотентно применить HAProxy + keepalived

```bash
sed -n '1,240p' "$HA_DIR/site.yml"
sed -n '1,220p' "$HA_DIR/roles/vxlan_l2/tasks/main.yml"
sed -n '1,220p' "$HA_DIR/roles/haproxy/templates/haproxy.cfg.j2"
sed -n '1,220p' "$HA_DIR/roles/keepalived/templates/keepalived.conf.j2"
ansible-playbook -i "$INV" "$HA_DIR/site.yml" --syntax-check --private-key "$SSH_KEY"
ansible-playbook -i "$INV" "$HA_DIR/site.yml" --private-key "$SSH_KEY"
```

Ожидаю: `PLAY RECAP` без failed. На непрерывном стенде после части 1 большинство задач дают `ok`/`changed=0`; после явного reset те же роли установят конфигурацию заново. HAProxy работает в `mode tcp`, health check делает HTTP `GET /readyz`, keepalived управляет VIP 10.77.0.10 на vxlan100.

## V2-C4-S11-C04 · Доказать сервисы, единственного владельца VIP и HTTP 200

```bash
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl is-active haproxy keepalived'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100'
VIP_OWNERS=()
for host in lb1 lb2; do
  if ansible -i "$INV" "$host" --private-key "$SSH_KEY" --become \
    -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100' \
    | grep -q "$HA_VIP/24"; then
    VIP_OWNERS+=("$host")
  fi
done
test "${#VIP_OWNERS[@]}" -eq 1
printf 'VIP owner: %s\n' "${VIP_OWNERS[0]}"
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.uri -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"
ssh -i "$SSH_KEY" -o ExitOnForwardFailure=yes -N \
  -L "127.0.0.1:18081:$HA_VIP:$HA_PORT" \
  "${VIDEO2_SSH_USER:-root}@${LB1_SSH_HOST:?fill LB1_SSH_HOST}" &
VIP_TUNNEL_PID=$!
printf '%s\n' "$VIP_TUNNEL_PID" > "$HA_DIR/.vip-tunnel.pid"
sleep 2
curl -fsS http://127.0.0.1:18081/readyz
open http://127.0.0.1:18081/
```

Ожидаю: оба сервиса active, VIP есть ровно на одном LB, запрос через VIP возвращает HTTP 200. Браузер открывает тот же private VIP через локальный SSH-туннель; это мост лабы, а не public ingress.

## V2-C4-S12-C01 · Определить текущего владельца VIP и запустить измеряемую пробу

```bash
VIP_OWNERS=()
for host in lb1 lb2; do
  if ansible -i "$INV" "$host" --private-key "$SSH_KEY" --become \
    -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100' | grep -q "$HA_VIP/24"; then
    VIP_OWNERS+=("$host")
  fi
done
test "${#VIP_OWNERS[@]}" -eq 1
ACTIVE_LB="${VIP_OWNERS[0]}"
printf '%s\n' "$ACTIVE_LB" > "$HA_DIR/.failed-active-host"
printf 'VIP owner before failure: %s\n' "$ACTIVE_LB"
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a "rm -f /tmp/vip-probe.log; nohup sh -c 'for i in \$(seq 1 25); do printf \"%s \" \"\$(date +%T)\"; curl --max-time 2 -sS -o /dev/null -w \"%{http_code}\\n\" http://$HA_VIP:$HA_PORT/readyz || echo timeout; sleep 1; done' >/tmp/vip-probe.log 2>&1 </dev/null &"
```

Ожидаю: владелец определяется фактом, а не предположением `lb1`; на lb1 в фоне началась секундная HTTP-проба.

## V2-C4-S12-C02 · Остановить HAProxy активного LB и доказать переезд VIP

```bash
ansible -i "$INV" "$ACTIVE_LB" --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl stop haproxy'
NEW_OWNER=''
for _ in $(seq 1 30); do
  VIP_OWNERS=()
  for host in lb1 lb2; do
    if ansible -i "$INV" "$host" --private-key "$SSH_KEY" --become \
      -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100' \
      | grep -q "$HA_VIP/24"; then
      VIP_OWNERS+=("$host")
    fi
  done
  if [ "${#VIP_OWNERS[@]}" -eq 1 ] \
    && [ "${VIP_OWNERS[0]}" != "$ACTIVE_LB" ] \
    && ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
      -m ansible.builtin.uri \
      -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200" \
      >/dev/null 2>&1; then
    NEW_OWNER="${VIP_OWNERS[0]}"
    break
  fi
  sleep 1
done
test -n "$NEW_OWNER"
printf 'VIP owner after failure: %s\n' "$NEW_OWNER"
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.shell \
  -a "journalctl -u keepalived --since '3 minutes ago' --no-pager | tail -24"
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'cat /tmp/vip-probe.log'
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.uri -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"
```

Ожидаю: VIP находится на втором LB, журнал фиксирует смену состояния, в probe виден фактический краткий разрыв/timeout и последующие 200; итоговый HTTP снова 200.

## V2-C4-S13-C01 · Восстановить отказавший LB без требования вернуть VIP на lb1

```bash
FAILED_LB="$(cat "$HA_DIR/.failed-active-host")"
[[ "$FAILED_LB" == "lb1" || "$FAILED_LB" == "lb2" ]]
ansible -i "$INV" "$FAILED_LB" --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl start haproxy'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl is-active haproxy keepalived'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100'
VIP_OWNERS=()
for host in lb1 lb2; do
  if ansible -i "$INV" "$host" --private-key "$SSH_KEY" --become \
    -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100' \
    | grep -q "$HA_VIP/24"; then
    VIP_OWNERS+=("$host")
  fi
done
test "${#VIP_OWNERS[@]}" -eq 1
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.uri -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"
curl -fsS http://127.0.0.1:18081/readyz
VIP_TUNNEL_PID="$(cat "$HA_DIR/.vip-tunnel.pid" 2>/dev/null || true)"
[[ -z "$VIP_TUNNEL_PID" ]] || kill "$VIP_TUNNEL_PID" 2>/dev/null || true
rm -f "$HA_DIR/.vip-tunnel.pid"
rm -f "$HA_DIR/.failed-active-host"
kubectl --context "$CTX" -n traffic-lab delete pod client --ignore-not-found
```

Ожидаю: HAProxy и keepalived active на обоих LB, VIP ровно на одном, HTTP 200 и с LB, и через браузерный туннель. Из-за `nopreempt` VIP не обязан вернуться на lb1; туннель и debug-client удалены.
