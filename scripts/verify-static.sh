#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)

command_count=$(find "$repo_root" -type f -name commands.sh | wc -l | tr -d ' ')
[[ $command_count == 45 ]] || {
  echo "expected exactly 45 commands.sh files, got $command_count" >&2
  exit 1
}
find "$repo_root" -type f -name commands.sh -print0 | xargs -0 -n1 bash -n
[[ $(find "$repo_root" -type l | wc -l | tr -d ' ') == 0 ]] || {
  echo "clone must not contain symlinks" >&2
  exit 1
}

(
  cd "$repo_root/00_NIGHT_SHIFT_APP"
  go test -race ./...
  go vet ./...
)

while IFS= read -r -d '' kustomization; do
  kubectl kustomize "$(dirname "$kustomization")" >/dev/null
done < <(find "$repo_root" -type f -name kustomization.yaml -print0)

terraform fmt -check -recursive "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/04_1.3_five_vm_terraform/terraform"
terraform fmt -check -recursive "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/05_1.4_managed_cluster/terraform"

for terraform_root in \
  "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/01_1.1_hello_terraform" \
  "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/03_1.2bis_real_vm" \
  "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/04_1.3_five_vm_terraform/terraform" \
  "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/05_1.4_managed_cluster/terraform" \
  "$repo_root/03_ЧАСТЬ_3_SCALING/32_3.11_cluster_autoscaler/terraform"; do
  terraform -chdir="$terraform_root" init -backend=false -input=false >/dev/null
  terraform -chdir="$terraform_root" validate >/dev/null
done

echo "STATIC QA OK: exactly 45 command files, no symlinks, Go race/vet, every Kustomize package, all Terraform roots"
