#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)

find "$repo_root" -type f -name commands.sh -print0 | xargs -0 -n1 bash -n

(
  cd "$repo_root/00_NIGHT_SHIFT_APP"
  go test -race ./...
  go vet ./...
)

for package in \
  "$repo_root/00_NIGHT_SHIFT_APP/k8s/base" \
  "$repo_root/00_NIGHT_SHIFT_APP/k8s/overlays/recording" \
  "$repo_root/00_NIGHT_SHIFT_APP/k8s/scaling" \
  "$repo_root/00_NIGHT_SHIFT_APP/k8s/scheduling" \
  "$repo_root/00_NIGHT_SHIFT_APP/k8s/scheduling/production-reference"; do
  kubectl kustomize "$package" >/dev/null
done

terraform fmt -check -recursive "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/04_1.3_five_vm_terraform/terraform"
terraform fmt -check -recursive "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/05_1.4_managed_cluster/terraform"

echo "STATIC QA OK: 45 command files, Go race/vet, Kustomize and Terraform fmt"
