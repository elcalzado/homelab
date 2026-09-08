#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
output_file="$repo_root/configs/gatus/backup-jobs.nix"

jobs_json="$(nix eval --json .#backupJobs)"

{
  echo "["
  echo "$jobs_json" | jq -r '.[] | "  \(@json)"'
  echo "]"
} > "$output_file"

git add "$output_file"