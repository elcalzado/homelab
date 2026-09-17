#!/usr/bin/env bash
set -euo pipefail

repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
staged_root="${STAGED_DIR:-$repo_root}"

hosts_list=""
for dir in "$staged_root"/hosts/*/; do
  name="$(basename "$dir")"
  [[ "$name" == "archived" ]] && continue
  hosts_list+="$name"$'\n'
done
hosts_list="${hosts_list%$'\n'}"

quoted_list="$(printf '%s\n' "$hosts_list" | sed 's/^/"/; s/$/"/' | paste -sd, -)"

for file in deploy.yml rollback.yml; do
  yq -i ".on.workflow_dispatch.inputs.host.options = [$quoted_list]" "$repo_root/.github/workflows/$file"
done

git -C "$repo_root" add .github/workflows/deploy.yml .github/workflows/rollback.yml