#!/usr/bin/env bash
# Deploys one node from flake.nix's `deploy.nodes`, run by the GitHub Actions
# runner (.github/workflows/deploy.yml). Prints what would change before it
# activates, so the job log is the changelog.
#
# Usage: scripts/deploy.sh <node> [dry-activate|switch]   (default: dry-activate)
set -euo pipefail

node="${1:?usage: $0 <node> [dry-activate|switch]}"
mode="${2:-dry-activate}"

root="$(git rev-parse --show-toplevel)"
cd "$root"

key=/run/secrets/deploy/sshKey
ssh_opts=(-i "$key" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

nix_() { nix --extra-experimental-features 'nix-command flakes' "$@"; }

address=$(nix_ eval --raw ".#deploy.nodes.\"$node\".hostname")
system=$(nix_ eval --raw ".#deploy.nodes.\"$node\".profiles.system.path")

printf '== %s (%s) ==\n' "$node" "$address"

# Ship the closure first so the diff can run on the target. deploy-rs needs it
# there regardless, so this is not extra work.
nix_ copy --to "ssh://deploy@$address?ssh-key=$key" "$system"

printf '\n-- package changes --\n'
ssh "${ssh_opts[@]}" "deploy@$address" \
  nix --extra-experimental-features nix-command \
  store diff-closures /run/current-system "$system" || true

printf '\n-- %s --\n' "$mode"
case "$mode" in
dry-activate) nix_ run --inputs-from . deploy-rs -- --ssh-opts "${ssh_opts[*]}" --dry-activate ".#$node" ;;
switch) nix_ run --inputs-from . deploy-rs -- --ssh-opts "${ssh_opts[*]}" ".#$node" ;;
*)
  printf 'unknown mode: %s\n' "$mode" >&2
  exit 2
  ;;
esac
