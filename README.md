# Kubernetes production labs — Video 2

Чистый recording repository: отдельное Go-приложение DEVOPS MAY CRY и 45
последовательных лабораторных по Terraform, Ansible/Kubespray, scheduler,
ресурсам, scaling и пути трафика.

- `00_DEVOPS_MAY_CRY_APP` — Go, tests, Docker, Compose + PostgreSQL, Kustomize;
- `01_ЧАСТЬ_1_КЛАСТЕР` — IaC, Kubespray, managed/self-managed, MetalLB;
- `02_ЧАСТЬ_2_SCHEDULER` — taints, affinity, spread, Pending;
- `03_ЧАСТЬ_3_SCALING` — requests/limits, OOM, HPA/VPA/autoscaler;
- `04_ЧАСТЬ_4_TRAFFIC` — TCP/DNS/Service/EndpointSlice и внешний HA.

В каждой лабораторной `commands.sh` — не исполняемый setup-скрипт, а блоки
команд для копирования по одному во время записи. Секреты, private keys,
runtime inventory, Terraform state/plan/tfvars в git не входят.

Два handoff намеренно сохраняют runtime-state между соседними папками:
`06 -> 07` использует один Kubespray inventory, а `43 -> 44 -> 45` — один
HA inventory и маркер активного балансировщика. Команды указывают эти пути
явно; дублированных расходящихся копий нет.

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
