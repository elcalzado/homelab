#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

hosts_list=""
for dir in "$repo_root"/hosts/*/; do
  name="$(basename "$dir")"
  [[ "$name" == "archived" ]] && continue
  hosts_list+="$name"$'\n'
done
hosts_list="${hosts_list%$'\n'}"

quoted_list="$(printf '%s\n' "$hosts_list" | sed 's/^/"/; s/$/"/' | paste -sd, -)"

for file in deploy.yml rollback.yml; do
  yq -i ".on.workflow_dispatch.inputs.host.options = [$quoted_list]" "$repo_root/.github/workflows/$file"
done

git add .github/workflows/deploy.yml .github/workflows/rollback.yml