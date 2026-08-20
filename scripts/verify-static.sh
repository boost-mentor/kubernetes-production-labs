#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)

command_count=$(find "$repo_root" -type f -name commands.sh | wc -l | tr -d ' ')
[[ $command_count == 45 ]] || {
  echo "expected exactly 45 commands.sh files, got $command_count" >&2
  exit 1
}
find "$repo_root" -type f -name commands.sh -print0 | xargs -0 -n1 bash -n
source_symlink_count=$(
  find "$repo_root" \
    \( -path "$repo_root/.git" \
       -o -path "$repo_root/kubespray/vendor" \
       -o -path "$repo_root/kubespray/.venv" \
       -o -path '*/.terraform' \
       -o -path "$repo_root/output" \) -prune \
    -o -type l -print \
    | wc -l | tr -d ' '
)
[[ $source_symlink_count == 0 ]] || {
  echo "clone must not contain symlinks" >&2
  exit 1
}

(
  cd "$repo_root/apps/devops-may-cry"
  go test -race ./...
  go vet ./...
)

while IFS= read -r -d '' kustomization; do
  kubectl kustomize "$(dirname "$kustomization")" >/dev/null
done < <(find "$repo_root" -type f -name kustomization.yaml -print0)

terraform fmt -check -recursive "$repo_root/infra/self-managed/terraform"
terraform fmt -check -recursive "$repo_root/infra/managed/terraform"

for terraform_root in \
  "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР/01_1.1_hello_terraform" \
  "$repo_root/infra/self-managed/terraform" \
  "$repo_root/infra/managed/terraform" \
  "$repo_root/03_ЧАСТЬ_3_SCALING/32_3.11_cluster_autoscaler/terraform"; do
  terraform -chdir="$terraform_root" init -backend=false -input=false >/dev/null
  terraform -chdir="$terraform_root" validate >/dev/null
done

if rg -n '/Users/|\./(bootstrap|deploy|preflight|install-and-demo|show-state|demo-failover|restore-after-demo)\.sh' \
  "$repo_root/commands" "$repo_root/teleprompter"; then
  echo "REC artifacts must not contain host-specific paths or opaque helper calls" >&2
  exit 1
fi

if rg -n -i 'честн|магия|техподдерж|Зевс|Мнемоз|потрох|прямо при|блюдеч' \
  "$repo_root/README.md" \
  "$repo_root/commands" \
  "$repo_root/teleprompter/source" \
  "$repo_root/recording" \
  "$repo_root/01_ЧАСТЬ_1_КЛАСТЕР" \
  "$repo_root/02_ЧАСТЬ_2_SCHEDULER" \
  "$repo_root/03_ЧАСТЬ_3_SCALING" \
  "$repo_root/04_ЧАСТЬ_4_TRAFFIC"; then
  echo "presenter-facing text contains banned AI-style phrasing" >&2
  exit 1
fi

python3 "$repo_root/scripts/build-recording-artifacts.py" --check

for part in 1 2 3 4; do
  command_deck="$repo_root/commands/VIDEO2_PART${part}_COMMANDS.md"
  teleprompter="$repo_root/teleprompter/VIDEO2_PART${part}.md"
  [[ -f $command_deck && -f $teleprompter ]] || {
    echo "recording artifacts for part $part are missing" >&2
    exit 1
  }
  command_ids=$(rg -o 'V2-C[1-4]-S[0-9]{2}-C[0-9]{2}' "$command_deck" | sort)
  teleprompter_ids=$(rg -o 'V2-C[1-4]-S[0-9]{2}-C[0-9]{2}' "$teleprompter" | sort)
  [[ -n $command_ids && $command_ids == "$teleprompter_ids" ]] || {
    echo "part $part command IDs and teleprompter IDs must be a one-to-one match" >&2
    diff -u <(printf '%s\n' "$command_ids") <(printf '%s\n' "$teleprompter_ids") || true
    exit 1
  }
done

echo "STATIC QA OK: 45 labs, no symlinks, Go/Kustomize/Terraform, REC command bijection 4/4"
