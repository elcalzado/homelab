#!/usr/bin/env bash
set -euo pipefail

repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
staged_root="${STAGED_DIR:-$repo_root}"
output_file="$repo_root/configs/gatus/backup-jobs.nix"

jobs_json="$(nix eval --json "$staged_root#backupJobs")"

{
  echo "["
  echo "$jobs_json" | jq -r '.[] | "  \(@json)"'
  echo "]"
} > "$output_file"

git -C "$repo_root" add "$output_file"