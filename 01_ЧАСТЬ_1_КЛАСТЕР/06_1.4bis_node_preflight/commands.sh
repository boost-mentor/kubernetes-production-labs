#!/usr/bin/env bash
# ЛАБА 1.4-БИС · Подготовка трёх машин: то, из-за чего Kubespray падает на середине
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

REPO_ROOT="$(git rev-parse --show-toplevel)"
KUBESPRAY_ROOT="$REPO_ROOT/kubespray"
INV="$KUBESPRAY_ROOT/inventory/video2/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
source "$KUBESPRAY_ROOT/.venv/bin/activate"

test -r "$SSH_KEY"
chmod 600 "$SSH_KEY"
test -f "$INV"
test "$(git -C "$KUBESPRAY_ROOT/vendor/kubespray" describe --tags --exact-match)" = "$(cat "$KUBESPRAY_ROOT/VERSION")"
ansible --version | head -5

sed -n '1,160p' "$INV"
ansible-inventory -i "$INV" --graph

ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.ping
ansible -i "$INV" all --private-key "$SSH_KEY" --become -m ansible.builtin.command -a whoami
ansible -i "$INV" all --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a 'test -z "$(swapon --show --noheadings)"; test "$(stat -fc %T /sys/fs/cgroup)" = cgroup2fs; ip -4 route show default'

# ansible_host — public/floating IP только для SSH.
# ip/access_ip — private IP для трафика между VM.
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.setup \
  -a 'filter=ansible_default_ipv4'
