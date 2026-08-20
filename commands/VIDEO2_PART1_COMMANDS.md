# VIDEO2 · Часть 1 · команды для записи

Это единственный командник для основной записи части 1. Иди сверху вниз и копируй только тот блок, чей ID сейчас показан в суфлёре. Команды выполняются по блокам, не весь файл целиком.

Перед REC один раз создай локальный `recording/.recording.env` из примера и впиши свои значения. Файл игнорируется Git. Секреты, приватные ключи, state и реальные inventory в кадр не выводим.

## V2-C1-S01-C01 · Зафиксировать корень клона и параметры записи

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
test -f recording/.recording.env || cp recording/recording.env.example recording/.recording.env
set -a
source recording/.recording.env
set +a
printf 'repo=%s\nself=%s\nmanaged=%s\n' "$REPO_ROOT" "$SELF_CONTEXT" "$MANAGED_CONTEXT"
```

Ожидаю: абсолютный путь текущего клона и контексты `kubespray` / `yc-managed`. Если env-файл только что создан, остановись до REC и заполни его.

## V2-C1-S02-C01 · Terraform init и plan на двух обычных файлах

```bash
cd "$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/01_1.1_hello_terraform"
rm -f zhurnal.txt svodka.txt terraform.tfstate terraform.tfstate.backup
terraform init
terraform plan
```

Ожидаю: `Plan: 2 to add, 0 to change, 0 to destroy`. В кадре показываем `main.tf` до запуска.

## V2-C1-S02-C02 · Terraform apply, state и идемпотентность

```bash
terraform apply
cat zhurnal.txt
cat svodka.txt
terraform plan
terraform output
```

Ожидаю: после `yes` создаются два файла; повторный plan сообщает `No changes`.

## V2-C1-S02-C03 · Дрифт, восстановление из кода и cleanup

```bash
echo "тут никого не было" > zhurnal.txt
terraform plan
terraform apply
head -2 zhurnal.txt
terraform destroy
```

Ожидаю: Terraform видит ручную правку как расхождение, восстанавливает объявленное содержимое, затем удаляет свои два ресурса.

## V2-C1-S03-C01 · Ansible inventory, ping и первый play

```bash
cd "$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/02_1.2_hello_ansible"
rm -rf /tmp/night_office
cat inventory.ini
ansible -i inventory.ini all -m ansible.builtin.ping
ansible-playbook -i inventory.ini playbook.yml
cat /tmp/night_office/prays.txt
```

Ожидаю: localhost отвечает `pong`, первый `PLAY RECAP` даёт `failed=0` и `changed=4`.

## V2-C1-S03-C02 · Второй play ничего не меняет

```bash
ansible-playbook -i inventory.ini playbook.yml
```

Ожидаю: `changed=0` и handler не запускается. Это и есть проверяемая идемпотентность.

## V2-C1-S03-C03 · Изменение переменной вызывает только нужные изменения

```bash
sed -i '' 's/: 4000/: 6000/' vars/prices.yml
ansible-playbook -i inventory.ini playbook.yml
cat /tmp/night_office/rassylka.txt
sed -i '' 's/: 6000/: 4000/' vars/prices.yml
rm -rf /tmp/night_office
```

Ожидаю: `changed=2`, handler срабатывает, итоговая сумма меняется; в конце исходное значение возвращено.

## V2-C1-S04-C01 · Kubespray — обычный большой Ansible-проект

```bash
cd "$REPO_ROOT"
KUBESPRAY_ROOT="$REPO_ROOT/kubespray"
UPSTREAM="$KUBESPRAY_ROOT/vendor/kubespray"
cat "$KUBESPRAY_ROOT/VERSION"
sed -n '1,180p' "$UPSTREAM/cluster.yml"
find "$UPSTREAM/roles" -mindepth 1 -maxdepth 1 -type d -print | sort | sed -n '1,24p'
sed -n '1,180p' "$KUBESPRAY_ROOT/inventory/video2/inventory.example.ini"
sed -n '1,180p' "$KUBESPRAY_ROOT/inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml"
```

Ожидаю: pinned tag `v2.31.0`, верхнеуровневый `cluster.yml`, обычные роли, inventory и group_vars. Здесь ничего не устанавливаем.

## V2-C1-S05-C01 · До Terraform проверить облачный UI без второго ручного стенда

```bash
export YC_TOKEN="$(yc iam create-token)"
export YC_CLOUD_ID="$(yc config get cloud-id)"
export YC_FOLDER_ID="$(yc config get folder-id)"
test -n "$YC_TOKEN" && test -n "$YC_CLOUD_ID" && test -n "$YC_FOLDER_ID"
yc compute instance list --folder-id "$YC_FOLDER_ID" --format json \
  | jq -r '.[] | [.name, .status] | @tsv'
printf 'Yandex CLI and Terraform environment: OK\n'
```

Ожидаю: свежий IAM-токен остаётся только в окружении текущего терминала, CLI отвечает, затем виден либо пустой список, либо существующие учебные VM. В браузере руками открываем Compute Cloud и только показываем поля создания VM — второй комплект ресурсов кликами не создаём.

## V2-C1-S06-C01 · Проверить production-shaped Terraform до apply

```bash
cd "$REPO_ROOT/infra/self-managed/terraform"
test -f terraform.tfvars || cp terraform.tfvars.example terraform.tfvars
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -out=/tmp/video2-self-managed.tfplan >/tmp/video2-self-managed-plan.log
terraform show -json /tmp/video2-self-managed.tfplan \
  | jq -r '.resource_changes[] | [.address, (.change.actions | join(","))] | @tsv'
```

Ожидаю: план ровно пяти VM — `node1`, `node2`, `node3`, `lb1`, `lb2` — плюс сеть, подсеть и правила доступа. В `terraform.tfvars` уже должны быть твой public IP `/32` и SSH public key.

## V2-C1-S06-C02 · Временно создать пять VM и проверить Terraform outputs

```bash
terraform apply -no-color /tmp/video2-self-managed.tfplan \
  >/tmp/video2-self-managed-apply.log
grep -E '^(Apply complete|Outputs:|[[:alnum:]_]+ = <sensitive>)' \
  /tmp/video2-self-managed-apply.log
terraform output -json nodes | jq 'with_entries(.value |= {
  roles,
  external_ip: "<redacted>",
  internal_ip: "<redacted>",
  instance_id: "<redacted>"
})'
terraform output -raw kubespray_inventory \
  | sed -E 's/(ansible_host|ip|access_ip)=[^ ]+/\1=<redacted>/g'
terraform output -raw external_ha_inventory \
  | sed -E 's/(ansible_host|private_ip)=[^ ]+/\1=<redacted>/g'
yc compute instance list --folder-id "$YC_FOLDER_ID" --format json \
  | jq -r '.[] | [.name, .status] | @tsv'
```

Ожидаю: временные `node1-node3` и `lb1-lb2`, сеть и два inventory как outputs. В кадре видны роли и структура, а IP/instance ID заменены на `<redacted>`. Рабочим стендом записи остаются пять VM из урока BoostMentor.

## V2-C1-S06-C03 · Удалить только временный Terraform-стенд

```bash
terraform plan -destroy -out=/tmp/video2-self-managed-destroy.tfplan \
  >/tmp/video2-self-managed-destroy-plan.log
terraform show -json /tmp/video2-self-managed-destroy.tfplan \
  | jq -r '.resource_changes[] | [.address, (.change.actions | join(","))] | @tsv'
terraform apply -no-color /tmp/video2-self-managed-destroy.tfplan \
  >/tmp/video2-self-managed-destroy.log
grep -E '^Destroy complete' /tmp/video2-self-managed-destroy.log
yc compute instance list --folder-id "$YC_FOLDER_ID" --format json \
  | jq -r '.[] | [.name, .status] | @tsv'
```

Ожидаю: Terraform удаляет только ресурсы этого state. Пять VM учебной платформы живут отдельно и остаются для Kubespray и внешнего HA.

## V2-C1-S07-C01 · Managed-кластер тем же IaC-подходом

```bash
cd "$REPO_ROOT/infra/managed/terraform"
test -f private.auto.tfvars || cp private.auto.tfvars.example private.auto.tfvars
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -out=/tmp/video2-managed.tfplan >/tmp/video2-managed-plan.log
terraform show -json /tmp/video2-managed.tfplan \
  | jq -r '.resource_changes[] | [.address, (.change.actions | join(","))] | @tsv'
terraform apply -no-color /tmp/video2-managed.tfplan >/tmp/video2-managed-apply.log
grep -E '^(Apply complete|Outputs:|[[:alnum:]_]+ = <sensitive>)' \
  /tmp/video2-managed-apply.log
yc managed-kubernetes cluster list --format json \
  | jq -r '.[] | [.name, .status] | @tsv'
yc managed-kubernetes node-group list --format json \
  | jq -r '.[] | [.name, .status] | @tsv'
terraform output cidrs
```

Ожидаю: managed control plane и node group. В браузере проверяем те же ресурсы в Yandex Cloud, не редактируем их руками.

## V2-C1-S08-C01 · Прочитать роли нод и проверить SSH/sudo

```bash
cd "$REPO_ROOT"
KUBESPRAY_ROOT="$REPO_ROOT/kubespray"
INV="$KUBESPRAY_ROOT/inventory/video2/inventory.ini"
source "$REPO_ROOT/recording/.recording.env"
SSH_KEY="$VIDEO2_SSH_KEY"
SSH_USER="${VIDEO2_SSH_USER:-root}"
: "${NODE1_SSH_HOST:?fill recording/.recording.env}"
: "${NODE2_SSH_HOST:?fill recording/.recording.env}"
: "${NODE3_SSH_HOST:?fill recording/.recording.env}"
: "${LB1_SSH_HOST:?fill recording/.recording.env}"
: "${LB2_SSH_HOST:?fill recording/.recording.env}"
install -d -m 0700 "$KUBESPRAY_ROOT/inventory/video2/group_vars/all"
cat > "$INV" <<EOF
[all]
node1 ansible_host=$NODE1_SSH_HOST ansible_user=$SSH_USER
node2 ansible_host=$NODE2_SSH_HOST ansible_user=$SSH_USER
node3 ansible_host=$NODE3_SSH_HOST ansible_user=$SSH_USER

[kube_control_plane]
node1
node2

[etcd]
node1
node2
node3

[kube_node]
node2
node3

[k8s_cluster:children]
kube_control_plane
kube_node
EOF
cat > "$KUBESPRAY_ROOT/inventory/video2/group_vars/all/all.yml" <<EOF
---
supplementary_addresses_in_ssl_keys:
  - $NODE1_SSH_HOST
EOF
cat > "$REPO_ROOT/ansible/external-ha/inventory.ini" <<EOF
[load_balancers]
lb1 ansible_host=$LB1_SSH_HOST ansible_user=$SSH_USER ha_overlay_ip=10.77.0.11 ha_priority=150
lb2 ansible_host=$LB2_SSH_HOST ansible_user=$SSH_USER ha_overlay_ip=10.77.0.12 ha_priority=100

[kubernetes_nodes]
node1 ansible_host=$NODE1_SSH_HOST ansible_user=$SSH_USER
node2 ansible_host=$NODE2_SSH_HOST ansible_user=$SSH_USER
node3 ansible_host=$NODE3_SSH_HOST ansible_user=$SSH_USER

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ha_vip=$HA_VIP
ha_vip_prefix=24
ha_frontend_port=$HA_PORT
k8s_nodeport=$K8S_NODEPORT
EOF
chmod 600 "$SSH_KEY"
source "$KUBESPRAY_ROOT/.venv/bin/activate"
sed -n '1,160p' "$KUBESPRAY_ROOT/inventory/video2/inventory.example.ini"
ansible-inventory -i "$INV" --graph
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.ping
ansible -i "$INV" all --private-key "$SSH_KEY" --become -m ansible.builtin.command -a whoami
```

Ожидаю: структура видна по безопасному example и graph без hostvars; два реальных inventory построены из пяти адресов одной учебной лаборатории, но адреса не печатаются. node1/node2 в control plane, все три в etcd, node2/node3 в workers; все отвечают `pong` и `root` через become.

## V2-C1-S09-C01 · Проверить Linux-предпосылки и private networking

```bash
ansible -i "$INV" all --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a 'test -z "$(swapon --show --noheadings)"; test "$(stat -fc %T /sys/fs/cgroup)" = cgroup2fs; ip -4 route show default'
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.setup \
  -a 'filter=ansible_default_ipv4'
```

Ожидаю: swap пуст, cgroup v2, default route есть; `ansible_default_ipv4.address` — private IP. Public/floating IP применяется только для SSH.

## V2-C1-S09-C02 · Перед запуском прочитать playbook и параметры кластера

```bash
UPSTREAM="$KUBESPRAY_ROOT/vendor/kubespray"
sed -n '1,220p' "$UPSTREAM/cluster.yml"
sed -n '1,220p' "$UPSTREAM/playbooks/cluster.yml"
sed -n '1,220p' "$KUBESPRAY_ROOT/inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml"
find "$UPSTREAM/roles" -mindepth 1 -maxdepth 1 -type d -print | sort | sed -n '1,24p'
```

Ожидаю: видны `kube_version`, containerd, Calico, Pod/Service CIDR, strictARP, `kubeconfig_localhost` и `kubeconfig_localhost_ansible_host`. Последняя настройка заставит локальный `admin.conf` использовать SSH-адрес node1, а не недоступный с ноутбука private IP. Никакой установки ещё не было.

## V2-C1-S09-C03 · Прямой запуск Kubespray и безопасный kubeconfig

```bash
PLAYBOOK="$KUBESPRAY_ROOT/.venv/bin/ansible-playbook"
pushd "$UPSTREAM" >/dev/null
"$PLAYBOOK" -i "$INV" cluster.yml --become --private-key "$SSH_KEY"
popd >/dev/null
KUBECONFIG_FILE="$KUBESPRAY_ROOT/inventory/video2/artifacts/admin.conf"
OLD_CONTEXT="$(KUBECONFIG="$KUBECONFIG_FILE" kubectl config current-context)"
KUBECONFIG="$KUBECONFIG_FILE" kubectl config rename-context "$OLD_CONTEXT" kubespray
mkdir -p "$HOME/.kube"
KUBECONFIG="$HOME/.kube/config:$KUBECONFIG_FILE" kubectl config view --flatten > /tmp/video2-kubeconfig
install -m 0600 /tmp/video2-kubeconfig "$HOME/.kube/config"
kubectl --context kubespray get nodes -o wide
```

Ожидаю: `PLAY RECAP` без failed, затем три Ready-ноды. TLS не отключаем и `--insecure-skip-tls-verify` не используем.

## V2-C1-S10-C01 · Доказать, что кластер действительно работает

```bash
kubectl --context kubespray get nodes -o wide
kubectl --context kubespray get --raw='/readyz?verbose' | tail -12
kubectl --context kubespray -n kube-system get pods -o wide
kubectl --context kubespray -n kube-system get daemonset calico-node
kubectl --context kubespray -n kube-system get deployment coredns
kubectl --context kubespray apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context kubespray -n traffic-lab rollout status deployment/devops-may-cry --timeout=180s
kubectl --context kubespray -n traffic-lab get pods,service,endpointslice -o wide
```

Ожидаю: API ready, системные Pod'ы Running, Calico на каждой ноде, CoreDNS доступен, приложение разложено по workers и EndpointSlice содержит ready endpoints.

## V2-C1-S10-C02 · Проверить Service из временного клиента

```bash
kubectl --context kubespray -n traffic-lab run verify-client \
  --image=curlimages/curl:8.12.1 --restart=Never --command -- sleep 3600
kubectl --context kubespray -n traffic-lab wait --for=condition=Ready pod/verify-client --timeout=120s
kubectl --context kubespray -n traffic-lab exec verify-client -- curl -fsS http://devops-may-cry/readyz
kubectl --context kubespray -n traffic-lab delete pod verify-client --wait=true
```

Ожидаю: HTTP JSON со `status=ok`, затем одноразовый клиент удалён.

## V2-C1-S11-C01 · Посчитать сеть на конкретном IPv4-примере

```bash
python3 - <<'PY'
import ipaddress

for value in ("192.168.1.70/26", "10.233.64.0/18", "10.233.0.0/18"):
    net = ipaddress.ip_network(value, strict=False)
    print(value)
    print("  network   ", net.network_address)
    print("  netmask   ", net.netmask)
    print("  broadcast ", net.broadcast_address)
    print("  addresses ", net.num_addresses)
    print("  first/last", net.network_address + 1, net.broadcast_address - 1)
PY
```

Ожидаю для `192.168.1.70/26`: сеть `192.168.1.64`, usable `.65–.126`, broadcast `.127`, всего 64 адреса.

## V2-C1-S12-C01 · Связать Node PodCIDR с реальными Pod IP

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/09_1.7_cidr_to_node"
INV="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
kubectl --context kubespray get nodes \
  -o custom-columns='NODE:.metadata.name,INTERNAL-IP:.status.addresses[?(@.type=="InternalIP")].address,POD-CIDR:.spec.podCIDR'
kubectl --context kubespray get ippools.crd.projectcalico.org -o yaml | \
  grep -E 'cidr:|blockSize:|ipipMode:|vxlanMode:'
kubectl --context kubespray get blockaffinities.crd.projectcalico.org \
  -o custom-columns='NODE:.spec.node,CIDR:.spec.cidr,STATE:.spec.state'
```

Ожидаю: три разных `Node.spec.podCIDR` и отдельно Calico pool/blockSize. Это связанные, но не одинаковые сущности.

## V2-C1-S12-C02 · Посмотреть veth, маршрут и overlay на живых Pod'ах

```bash
kubectl --context kubespray apply -f "$LAB_DIR/calico-proof.yaml"
kubectl --context kubespray -n network-proof wait --for=condition=Ready pod --all --timeout=120s
kubectl --context kubespray -n network-proof get pods -o wide
POD_B_IP="$(kubectl --context kubespray -n network-proof get pod calico-b -o jsonpath='{.status.podIP}')"
kubectl --context kubespray -n network-proof exec calico-a -- ip address show eth0
kubectl --context kubespray -n network-proof exec calico-a -- ping -c 3 "$POD_B_IP"
source "$REPO_ROOT/kubespray/.venv/bin/activate"
ansible -i "$INV" node2 --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a "ip route get $POD_B_IP; ip -o link | grep cali | head; ip -d link show vxlan.calico || true"
kubectl --context kubespray delete namespace network-proof --wait=true
```

Ожидаю: Pod IP, `eth0` внутри Pod, `cali…`-интерфейсы/route на хосте и успешный ping между нодами. VXLAN показываем только если этот dataplane реально активен.

## V2-C1-S13-C01 · Получить managed kubeconfig и назвать контексты

```bash
cd "$REPO_ROOT/infra/managed/terraform"
$(terraform output -raw get_credentials_command)
kubectl config rename-context "$(kubectl config current-context)" yc-managed
kubectl --context yc-managed get nodes -o wide
kubectl config get-contexts
```

Ожидаю: `kubespray` и `yc-managed` существуют одновременно, а у managed видны только worker-ноды.

## V2-C1-S14-C01 · Maintenance drill: cordon, drain, PDB, uncordon

```bash
kubectl --context kubespray apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context kubespray -n traffic-lab rollout status deployment/devops-may-cry --timeout=180s
kubectl --context kubespray cordon node2
kubectl --context kubespray -n traffic-lab get pods -l app=devops-may-cry -o wide
kubectl --context kubespray drain node2 --ignore-daemonsets --delete-emptydir-data
kubectl --context kubespray -n traffic-lab get pods -l app=devops-may-cry -o wide
kubectl --context kubespray -n traffic-lab get pdb devops-may-cry
kubectl --context kubespray uncordon node2
```

Ожидаю: node2 становится unschedulable, обычные Pod'ы переезжают с учётом PDB, DaemonSet не выселяется, затем node2 возвращается.

## V2-C1-S15-C01 · До upgrade: версии, API и snapshot etcd

```bash
KUBESPRAY_ROOT="$REPO_ROOT/kubespray"
UPSTREAM="$KUBESPRAY_ROOT/vendor/kubespray"
INV="$KUBESPRAY_ROOT/inventory/video2/inventory.ini"
GROUP_VARS="$KUBESPRAY_ROOT/inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
source "$KUBESPRAY_ROOT/.venv/bin/activate"
kubectl --context kubespray get nodes \
  -o custom-columns='NODE:.metadata.name,READY:.status.conditions[-1].status,VERSION:.status.nodeInfo.kubeletVersion'
kubectl --context kubespray get --raw='/readyz?verbose' | tail -12
ansible -i "$INV" node1 --private-key "$SSH_KEY" --become -m ansible.builtin.shell -a \
  'install -d -m 0700 /var/backups/etcd; /usr/local/bin/etcdctl.sh --endpoints=https://127.0.0.1:2379 snapshot save /var/backups/etcd/video2-pre-1.35.4.db; /usr/local/bin/etcdutl snapshot status /var/backups/etcd/video2-pre-1.35.4.db -w table'
ansible -i "$INV" node1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a '/usr/local/bin/kubeadm certs check-expiration'
```

Ожидаю: baseline `v1.34.7`, API ready, snapshot со status table и срок сертификатов.

## V2-C1-S15-C02 · Показать единственную смену версии

```bash
cp "$KUBESPRAY_ROOT/versions/k8s-cluster-1.35.4.yml" "$GROUP_VARS"
git -C "$REPO_ROOT" diff -- kubespray/inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml
```

Ожидаю: содержательный diff `kube_version: 1.34.7 → 1.35.4`, а не россыпь несвязанных правок.

## V2-C1-S15-C03 · Непрерывная HTTP-проба во время upgrade

```bash
# Терминал 1:
kubectl --context kubespray -n traffic-lab port-forward service/devops-may-cry 18080:80 &
printf '%s\n' "$!" > /tmp/video2-upgrade-port-forward.pid
wait "$(cat /tmp/video2-upgrade-port-forward.pid)"
# Терминал 2:
while true; do date +%T; curl -fsS http://127.0.0.1:18080/readyz || echo FAIL; sleep 1; done &
printf '%s\n' "$!" > /tmp/video2-upgrade-probe.pid
wait "$(cat /tmp/video2-upgrade-probe.pid)"
```

Ожидаю: видимый поток `status=ok`. Это наблюдение, не обещание нулевого downtime.

## V2-C1-S15-C04 · Запустить настоящий upgrade playbook

```bash
PLAYBOOK="$KUBESPRAY_ROOT/.venv/bin/ansible-playbook"
pushd "$UPSTREAM" >/dev/null
"$PLAYBOOK" -i "$INV" upgrade-cluster.yml \
  --become --private-key "$SSH_KEY"
popd >/dev/null
```

Ожидаю: последовательное обслуживание нод и `PLAY RECAP` без failed. Это уже upgrade, в отличие от одного `drain`.

## V2-C1-S15-C05 · Доказать восстановление после upgrade

```bash
kubectl --context kubespray get nodes \
  -o custom-columns='NODE:.metadata.name,READY:.status.conditions[-1].status,VERSION:.status.nodeInfo.kubeletVersion'
kubectl --context kubespray get --raw='/readyz?verbose' | tail -12
kubectl --context kubespray -n kube-system get pods -o wide
kubectl --context kubespray -n traffic-lab rollout status deployment/devops-may-cry --timeout=180s
kubectl --context kubespray -n traffic-lab get pods -o wide
kubectl --context kubespray get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -12
for pid_file in /tmp/video2-upgrade-probe.pid /tmp/video2-upgrade-port-forward.pid; do
  if test -f "$pid_file"; then
    kill "$(cat "$pid_file")" 2>/dev/null || true
    rm -f "$pid_file"
  fi
done
```

Ожидаю: все ноды Ready на `v1.35.4`, API ready, workload доступен. Warning events читаем, а не скрываем. В конце обе upgrade-пробы остановлены, порт `18080` освобождён.

## V2-C1-S16-C01 · Сравнить владение control plane, etcd и внешним IP

```bash
kubectl --context yc-managed apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context yc-managed -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context yc-managed -n traffic-lab patch svc devops-may-cry \
  --type merge -p '{"spec":{"type":"LoadBalancer"}}'
kubectl --context kubespray get nodes
kubectl --context yc-managed get nodes
kubectl --context kubespray -n kube-system get pods | grep etcd
kubectl --context yc-managed -n kube-system get pods | grep etcd || true
kubectl --context yc-managed -n traffic-lab wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' \
  service/devops-may-cry --timeout=300s
kubectl --context yc-managed -n traffic-lab get svc devops-may-cry -o wide
```

Ожидаю: self-managed показывает control-plane/etcd, managed скрывает их; облачный Service получает внешний адрес от провайдера.

## V2-C1-S16-C02 · Сравнить kubeconfig и ответственность

```bash
kubectl config get-contexts
kubectl config view --context yc-managed --minify -o yaml
kubectl config view --context kubespray --minify -o yaml
stat -f '%Sp %N' "$HOME/.kube/config"
yc managed-kubernetes cluster list --format json \
  | jq -r '.[] | [.name, .status] | @tsv'
yc managed-kubernetes node-group list --format json \
  | jq -r '.[] | [.name, .status] | @tsv'
```

Ожидаю: два разных способа доступа; содержимое сертификатов/токенов в кадре не раскрываем. Managed снимает часть эксплуатации платформы, но не отвечает за workload.

## V2-C1-S17-C01 · До MetalLB: Service LoadBalancer остаётся pending

```bash
cd "$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/11_1.9_metallb"
kubectl --context kubespray apply -k ./devops-may-cry-base
kubectl --context kubespray -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context kubespray apply -f ./devops-may-cry-loadbalancer.yaml
kubectl --context kubespray -n traffic-lab get svc devops-may-cry-metallb
```

Ожидаю: `EXTERNAL-IP <pending>`. В self-managed кластере нет cloud-controller, который сам выделит адрес.

## V2-C1-S17-C02 · Проверить pool и strictARP до установки

```bash
source "$REPO_ROOT/recording/.recording.env"
: "${NODE_SUBNET_CIDR:?fill recording/.recording.env}"
: "${METALLB_POOL_START:?fill recording/.recording.env}"
: "${METALLB_POOL_END:?fill recording/.recording.env}"
printf 'node subnet: %s\nreserved pool: %s-%s\n' \
  "$NODE_SUBNET_CIDR" "$METALLB_POOL_START" "$METALLB_POOL_END"
kubectl --context kubespray get nodes -o wide
kubectl --context kubespray -n kube-system get configmap kube-proxy -o yaml | grep -A3 -B3 strictARP
```

Ожидаю: pool входит в node subnet, зарезервирован вне DHCP/IPAM, `strictARP: true`. Ping не доказывает, что IP свободен.

## V2-C1-S17-C03 · Установить MetalLB L2 и получить EXTERNAL-IP

```bash
helm repo add metallb https://metallb.github.io/metallb
helm repo update metallb
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system --create-namespace \
  --version 0.16.1 --wait --timeout 5m
METALLB_CONFIG="$(mktemp "${TMPDIR:-/tmp}/video2-metallb.XXXXXX.yaml")"
sed -e "s/__POOL_START__/$METALLB_POOL_START/g" \
    -e "s/__POOL_END__/$METALLB_POOL_END/g" \
    ./metallb-demo.yaml > "$METALLB_CONFIG"
cat "$METALLB_CONFIG"
kubectl --context kubespray apply -f "$METALLB_CONFIG"
kubectl --context kubespray -n metallb-system get pods -o wide
kubectl --context kubespray -n metallb-system get ipaddresspool,l2advertisement -o wide
kubectl --context kubespray -n traffic-lab wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' \
  service/devops-may-cry-metallb --timeout=120s
kubectl --context kubespray -n traffic-lab get svc devops-may-cry-metallb -o wide
kubectl --context kubespray -n metallb-system logs \
  -l app.kubernetes.io/component=speaker --tail=40
```

Ожидаю: controller/speaker Ready и Service получает адрес из pool. Это доказывает распределение адреса, но ещё не внешнюю достижимость.

## V2-C1-S17-C04 · Проверить границу L2 в облачной сети и показать BGP reference

```bash
METALLB_IP="$(kubectl --context kubespray -n traffic-lab get service devops-may-cry-metallb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
INV="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
source "$REPO_ROOT/kubespray/.venv/bin/activate"
ansible -i "$INV" node1 --private-key "$SSH_KEY" -m ansible.builtin.shell \
  -a "ip neigh show $METALLB_IP; curl --max-time 5 -sv http://$METALLB_IP/readyz; rc=\$?; printf 'curl_rc=%s\n' \"\$rc\"; exit 0"
sed -n '1,220p' ./metallb-bgp-reference.yaml
rm -f "$METALLB_CONFIG"
```

Ожидаю одно из двух: HTTP 200 и `curl_rc=0` в разрешённом L2-домене либо контролируемый timeout с ненулевым `curl_rc` в cloud VPC, которая не пропускает нужный ARP/L2. Ansible-задача остаётся зелёной, потому что обе ветки здесь являются измерением. BGP-файл не применяем без реального peer/router.

## V2-C1-S18-C01 · Подготовить NodePort и прочитать HA inventory

```bash
cd "$REPO_ROOT"
HA_DIR="$REPO_ROOT/ansible/external-ha"
INV="$HA_DIR/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
source "$REPO_ROOT/recording/.recording.env"
source "$REPO_ROOT/kubespray/.venv/bin/activate"
kubectl --context kubespray apply -f "$REPO_ROOT/kubernetes/devops-may-cry/services/nodeport.yaml"
kubectl --context kubespray -n traffic-lab get service devops-may-cry-ha-nodeport
kubectl --context kubespray -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry-ha-nodeport -o wide
sed -n '1,180p' "$HA_DIR/inventory.example.ini"
ansible-inventory -i "$INV" --graph
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.ping
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.setup \
  -a 'filter=ansible_default_ipv4'
```

Ожидаю: NodePort `30080`, ready endpoints, безопасный example и graph с пятью host names без hostvars. Реальный inventory адреса не печатает; floating IP нужен только для SSH, private facts используются для VXLAN/backends.

## V2-C1-S18-C02 · Прочитать роли и развернуть HAProxy/keepalived

```bash
sed -n '1,240p' "$HA_DIR/site.yml"
sed -n '1,220p' "$HA_DIR/roles/haproxy/templates/haproxy.cfg.j2"
sed -n '1,220p' "$HA_DIR/roles/keepalived/templates/keepalived.conf.j2"
ansible-playbook -i "$INV" "$HA_DIR/site.yml" --syntax-check --private-key "$SSH_KEY"
ansible-playbook -i "$INV" "$HA_DIR/preflight-backends.yml" --private-key "$SSH_KEY"
ansible-playbook -i "$INV" "$HA_DIR/site.yml" --private-key "$SSH_KEY"
```

Ожидаю: preflight достигает всех private NodePort backends; затем `PLAY RECAP` без failed. HAProxy работает в L4 `mode tcp`, health check идёт на `/readyz`.

## V2-C1-S18-C03 · Доказать VIP и HTTP до отказа

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
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"
```

Ожидаю: оба сервиса active, VIP `10.77.0.10` находится ровно на одном LB, HTTP 200. Это лабораторный VIP внутри VXLAN-пары, не публичный cloud IP.

## V2-C1-S18-C04 · Найти активный LB и показать failover

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
printf 'VIP owner before failure: %s\n' "$ACTIVE_LB"
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a "rm -f /tmp/vip-probe.log; nohup sh -c 'for i in \$(seq 1 25); do printf \"%s \" \"\$(date +%T)\"; curl --max-time 2 -sS -o /dev/null -w \"%{http_code}\\n\" http://$HA_VIP:$HA_PORT/readyz || echo timeout; sleep 1; done' >/tmp/vip-probe.log 2>&1 </dev/null &"
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
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a "journalctl -u keepalived --since '3 minutes ago' --no-pager | tail -24"
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'cat /tmp/vip-probe.log'
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"
```

Ожидаю: VIP переезжает на другой LB, в keepalived есть смена состояния, в probe log виден фактический разрыв и последующие 200. Не обещаем `<1s`.

## V2-C1-S18-C05 · Restore и итоговая проверка

```bash
ansible -i "$INV" "$ACTIVE_LB" --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl start haproxy'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl is-active haproxy keepalived'
VIP_OWNERS=()
for host in lb1 lb2; do
  if ansible -i "$INV" "$host" --private-key "$SSH_KEY" --become \
    -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100' \
    | grep -q "$HA_VIP/24"; then
    VIP_OWNERS+=("$host")
  fi
done
test "${#VIP_OWNERS[@]}" -eq 1
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"
```

Ожидаю: оба сервиса active, владелец VIP по-прежнему ровно один и HTTP 200. Из-за `nopreempt` VIP после восстановления не обязан вернуться на lb1.

## V2-C1-S19-C01 · Cleanup только после остановки записи

```bash
kubectl --context kubespray -n traffic-lab delete service devops-may-cry-metallb --ignore-not-found
helm uninstall metallb -n metallb-system || true
kubectl --context kubespray delete namespace metallb-system --ignore-not-found
cd "$REPO_ROOT/infra/managed/terraform"
terraform destroy
cd "$REPO_ROOT/infra/self-managed/terraform"
terraform destroy
```

Ожидаю: cleanup выполняется только после REC и после сохранения доказательств. Перед каждым destroy читаем plan; state и inventory не показываем в кадре.
