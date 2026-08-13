# Где лаборатория заканчивается и начинается production

Этот репозиторий показывает реальный код и реальные механики, но не выдаёт
пяти-VM стенд за готовую production-платформу.

## Что сделано как в боевом репозитории

- Go-код, тесты, multi-stage distroless image, Compose + PostgreSQL и миграция
  отделены от Kubernetes YAML;
- образ multi-arch, публикуется CI, получает provenance/SBOM и используется по
  immutable digest;
- Terraform разделён на root module, typed child module, variables, outputs,
  security groups и пример remote state с locking;
- Kubespray pin'ится по tag, inventory генерируется из facts, TLS-проверка не
  отключается, `strictARP` задаётся до сборки кластера;
- Ansible разделён на inventory, roles, templates и handlers; failover должен
  закончиться проверкой VIP, backends и HTTP, а не одним `changed=...`;
- workload работает non-root, без service-account token, с probes, resources,
  PDB, topology spread и Pod Security `restricted`.

## Упрощения стенда

- один control-plane/etcd и два worker — это учебный кластер. Production HA
  обычно требует минимум три control-plane/etcd в независимых failure domains;
- public/floating IP на каждой VM удобен для записи. В production nodes обычно
  private, доступ идёт через bastion/runner, egress — через NAT, security groups
  разделены для LB, control-plane и workers;
- VXLAN между `lb1/lb2` создаёт L2 только для failover-лабы и не переживает
  reboot как сетевой source of truth. Production сеть задаётся средствами
  провайдера/SDN, а VRRP/VIP разрешены и маршрутизируются явно;
- `root`, отключённый host-key checking и статический VRRP auth в HA-kit —
  лабораторные допущения. В production: automation user + become, known_hosts,
  Vault/SOPS и firewall для underlay/VRRP;
- PostgreSQL с `emptyDir` нужен только для scheduler-демо. Production — managed
  DB или operator, CSI/PVC, TLS, backup/PITR и отдельный failure domain;
- MetalLB уместен на bare metal/private L2 или с реальным BGP peer. В managed
  public cloud чаще выбирают cloud LoadBalancer; MetalLB не заменяет внешний
  HA-этаж `VIP -> keepalived -> HAProxy -> NodePort`.

## Как принимается восстановление

`apply` или зелёный Ansible recap недостаточны. Минимальное доказательство:

1. нужный image digest действительно скачан;
2. Deployment завершил rollout и Pods `Ready`;
3. EndpointSlice содержит только готовые backends;
4. бизнес-запрос `/order` даёт ожидаемый HTTP-ответ;
5. `/metrics` и логи подтверждают обработку после восстановления.

В диагностической истории сначала опровергаем удобную гипотезу «сломался Go»:
если контейнер не стартовал, application logs закономерно пусты; смотрим Events,
image pull/admission/egress и только затем эскалируем владельцу platform/network.
Временный image preload допустим лишь как ограниченный workaround с записанным
долгом; постоянное исправление — registry/IAM/allowlist и повторное доказательство.
