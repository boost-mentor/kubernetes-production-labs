# VIDEO2 · внешний HA-вход: HAProxy + keepalived

Этот каталог — каноническая практика внешнего HA-входа.

```text
клиент внутри lab VXLAN
  -> VIP 10.77.0.10:8080
  -> HAProxy на lb1 или lb2
  -> node1/node2/node3:30080
  -> Service -> Pod
```

## 0. Что уже должно быть

- из обычного урока запущен единый стенд `k8s-kubespray-cluster`; владелец
  выбрал режим «Бессрочно» для длинной записи;
- Kubernetes на `node1-node3` в Ready;
- применён `kubernetes/devops-may-cry/services/nodeport.yaml`, NodePort `30080`
  отвечает на каждой ноде;
- скачан один SSH-ключ стенда;
- известны публичные IP всех пяти VM.

IP из панели нужны только для SSH. После подключения Ansible сам собирает реальные
private IP всех пяти VM; VXLAN и HAProxy backend строятся по private-сети, а не по
floating/NAT-адресам.

HAProxy здесь сознательно работает в `mode tcp`: он не читает запрос и может
пропускать TLS до ingress-контроллера. При этом health check — HTTP
`GET /readyz`, поэтому из ротации исключается не только закрытый порт, но и
не-Ready приложение. Режим проксирования и способ проверки — разные решения.

## 1. Inventory

```bash
terraform -chdir=infra/self-managed/terraform output -raw external_ha_inventory \
  > ansible/external-ha/inventory.ini
cd ansible/external-ha
```

## 2. Pre-flight до записи

```bash
ansible-inventory -i inventory.ini --graph
ansible all -i inventory.ini -m ping --private-key "$VIDEO2_SSH_KEY"
ansible-playbook -i inventory.ini site.yml --syntax-check --private-key "$VIDEO2_SSH_KEY"
ansible-playbook -i inventory.ini preflight-backends.yml --private-key "$VIDEO2_SSH_KEY"
```

Он ничего не устанавливает: проверяет inventory, SSH, синтаксис ролей и три прямых
NodePort backend. Если backend не даёт HTTP — не трогай HAProxy, сначала почини
Service/Pod.

## 3. Живая установка в кадре

```bash
ansible-playbook -i inventory.ini site.yml --private-key "$VIDEO2_SSH_KEY"
```

Роли идут в понятном порядке: `vxlan_l2` → `haproxy` → `keepalived`.

## 4. Доказательство и failover

В REC переезд VIP делается прямыми `ansible` командами. Полные блоки лежат
в `commands/VIDEO2_PART1_COMMANDS.md`; reset-скрипты — только в
`recording/backstage`.

До REC те же проверки можно повторить одним backstage-helper из корня repo:

```bash
recording/backstage/external-ha/preflight.sh
```

VIP лабораторный: он живёт в VXLAN между `lb1` и `lb2`. Это не публичный floating
IP облака. Поэтому HTTP к VIP доказываем с LB-VM, а не выдаём его за доступный с
ноутбука production VIP. В production для публичного IP нужна поддержка/маршрутизация
провайдера или его managed Load Balancer.
