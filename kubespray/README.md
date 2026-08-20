# Kubespray: только наш inventory и group_vars

Исходный Kubespray не копируется в учебный репозиторий. Перед записью
backstage-helper клонирует официальный tag из `VERSION` в
`kubespray/vendor/kubespray` и ставит Python-зависимости в `kubespray/.venv`. В кадре мы открываем настоящий
upstream `cluster.yml`, роли и `upgrade-cluster.yml`, а запускаем прямые
`ansible`/`ansible-playbook` команды из `commands/VIDEO2_PART1_COMMANDS.md`.

## Порядок

Адреса трёх учебных VM из обычного урока BoostMentor записываются в
`kubespray/inventory/video2/inventory.ini`; private IP дальше снимаются Ansible facts.
Terraform outputs показывают ту же структуру как IaC-reference, но этот временный стенд
удаляется до запуска Kubespray. Versioned cluster config лежит в Git:

- `inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml` — исходная версия;
- `versions/k8s-cluster-1.34.7.yml` — точка возврата;
- `versions/k8s-cluster-1.35.4.yml` — цель настоящего upgrade.

В inventory `ansible_host` — public/floating IP для SSH с ноутбука.
Private IP для трафика между VM Kubespray получает из facts. Public IP `node1`
попадает в SAN API-сервера до установки кластера, поэтому CA не удаляем и
`--insecure-skip-tls-verify` не используем.

`lb1/lb2` в Kubespray inventory не входят. Для них есть отдельный
`ansible/external-ha`.

Локальная подготовка вне REC:

```bash
recording/backstage/kubespray/bootstrap.sh
recording/backstage/kubespray/prepare-inventory.sh
recording/backstage/kubespray/preflight.sh
```

Эти helpers не являются частью объяснения. В REC показываются прямые
`ansible-inventory`, `ansible` и `ansible-playbook` команды.
