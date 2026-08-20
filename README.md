# Kubernetes production labs — Video 2

Чистый recording repository: отдельное Go-приложение DEVOPS MAY CRY и 45
последовательных лабораторных по Terraform, Ansible/Kubespray, scheduler,
ресурсам, scaling и пути трафика.

- `apps/devops-may-cry` — Go, tests, Docker, Compose + PostgreSQL, Kustomize;
- `infra` — отдельные self-managed и managed Terraform roots;
- `kubespray` — наш inventory/group_vars и зафиксированные версии;
- `ansible/external-ha` — роли HAProxy/keepalived и лабораторный VXLAN/VIP;
- `kubernetes/devops-may-cry` — канонические workload-манифесты;
- `01_ЧАСТЬ_1_КЛАСТЕР` — IaC, Kubespray, managed/self-managed, MetalLB;
- `02_ЧАСТЬ_2_SCHEDULER` — taints, affinity, spread, Pending;
- `03_ЧАСТЬ_3_SCALING` — requests/limits, OOM, HPA/VPA/autoscaler;
- `04_ЧАСТЬ_4_TRAFFIC` — TCP/DNS/Service/EndpointSlice и внешний HA.

Запись начинается с
[`recording/MASTER_RECORDING_PLAN.md`](recording/MASTER_RECORDING_PLAN.md).
Правки доски для части 1 собраны в
[`recording/BOARD_PART1_GATE.md`](recording/BOARD_PART1_GATE.md).

В каждой лабораторной `commands.sh` — не исполняемый setup-скрипт, а блоки
команд для копирования по одному во время записи. Секреты, private keys,
runtime inventory, Terraform state/plan/tfvars в git не входят.

Runtime-state намеренно сохраняется между соседними сценами. В записи один
обычный урок BoostMentor создаёт пять VM; их SSH-адреса лежат только в локальном
`recording/.recording.env`. Прямые команды собирают из них один Kubespray
inventory и один HA inventory. Отдельный Terraform root показывает
эквивалентный пяти-VM стенд, его outputs и управляемый destroy, но не подменяет
рабочую лабораторию. Маркер остановленного LB лежит только в
`recording/backstage`, а не в учебном коде. Дублированных расходящихся копий нет.

Обычный вход в лабораторию:
`https://boostmentor.ru/dashboard/courses/devops-school/lesson/g8-project-cluster-lab1`.

```bash
git clone https://github.com/boost-mentor/kubernetes-production-labs.git
code kubernetes-production-labs
```

Код запускается с ноутбука так же, как в видео №1; Linux-specific evidence
снимается по SSH на VM. Для редкого безопасного remote-edit сценария есть
[`docs/REMOTE_SSH.md`](docs/REMOTE_SSH.md).

Лабораторные намеренно остаются компактными. Где стенд отличается от
production — это перечислено без маскировки в
[`docs/PRODUCTION_DELTA.md`](docs/PRODUCTION_DELTA.md).
