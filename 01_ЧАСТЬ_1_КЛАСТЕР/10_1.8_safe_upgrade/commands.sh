#!/usr/bin/env bash
# ЛАБА 1.8 · maintenance drill + реальный upgrade Kubernetes 1.34.7 → 1.35.4
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/10_1.8_safe_upgrade"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

KUBESPRAY_ROOT="$REPO_ROOT/kubespray"
UPSTREAM="$KUBESPRAY_ROOT/vendor/kubespray"
INV="$KUBESPRAY_ROOT/inventory/video2/inventory.ini"
GROUP_VARS="$KUBESPRAY_ROOT/inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
PLAYBOOK="$KUBESPRAY_ROOT/.venv/bin/ansible-playbook"
source "$KUBESPRAY_ROOT/.venv/bin/activate"

kubectl --context kubespray apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context kubespray -n traffic-lab rollout status deployment/devops-may-cry --timeout=180s
kubectl --context kubespray get nodes \
  -o custom-columns='NODE:.metadata.name,READY:.status.conditions[-1].status,VERSION:.status.nodeInfo.kubeletVersion'
kubectl --context kubespray get --raw='/readyz?verbose' | tail -12
kubectl --context kubespray -n kube-system get pods --field-selector=status.phase!=Running
kubectl --context kubespray -n traffic-lab get pdb devops-may-cry

# Сначала доказываем maintenance механику вручную.
kubectl --context kubespray cordon node2
kubectl --context kubespray -n traffic-lab get pods -l app=devops-may-cry -o wide
kubectl --context kubespray drain node2 --ignore-daemonsets --delete-emptydir-data
kubectl --context kubespray -n traffic-lab get pods -l app=devops-may-cry -o wide
kubectl --context kubespray -n traffic-lab get pdb devops-may-cry
kubectl --context kubespray uncordon node2

# Это уже не maintenance: снимаем проверяемый snapshot etcd перед сменой версии.
ansible -i "$INV" node1 --private-key "$SSH_KEY" --become -m ansible.builtin.shell -a \
  'install -d -m 0700 /var/backups/etcd; /usr/local/bin/etcdctl.sh --endpoints=https://127.0.0.1:2379 snapshot save /var/backups/etcd/video2-pre-1.35.4.db; /usr/local/bin/etcdutl snapshot status /var/backups/etcd/video2-pre-1.35.4.db -w table'
ansible -i "$INV" node1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a '/usr/local/bin/kubeadm certs check-expiration'

cp "$KUBESPRAY_ROOT/versions/k8s-cluster-1.35.4.yml" "$GROUP_VARS"
git -C "$REPO_ROOT" diff -- kubespray/inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml

# Во втором окне можно оставить непрерывную пробу:
kubectl --context kubespray -n traffic-lab port-forward service/devops-may-cry 18080:80
# И в третьем: while true; do date +%T; curl -fsS http://127.0.0.1:18080/readyz || echo FAIL; sleep 1; done

"$PLAYBOOK" -i "$INV" "$UPSTREAM/upgrade-cluster.yml" \
  --become --private-key "$SSH_KEY"

kubectl --context kubespray get nodes \
  -o custom-columns='NODE:.metadata.name,READY:.status.conditions[-1].status,VERSION:.status.nodeInfo.kubeletVersion'
kubectl --context kubespray get --raw='/readyz?verbose' | tail -12
kubectl --context kubespray -n kube-system get pods -o wide
kubectl --context kubespray -n traffic-lab rollout status deployment/devops-may-cry --timeout=180s
kubectl --context kubespray -n traffic-lab get pods -o wide
kubectl --context kubespray get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -12
