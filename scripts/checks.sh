#!/usr/bin/env bash
# Repo checks shared by CI (.github/workflows/ci.yml) and the git pre-commit hook
# (scripts/git-hooks/pre-commit), so the two don't drift.
#
# Usage: scripts/checks.sh [eval|build [host]|list|lint|shellcheck|secrets|secrets-history|all]
#        (default: all except `build`, it needs a Linux builder and is CI-only)
#
# Everything runs through nix, so the only prerequisite is Nix with flakes.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

nix_() { nix --extra-experimental-features 'nix-command flakes' "$@"; }

# Run a nixpkgs tool from the flake's pinned nixpkgs (--inputs-from), not the floating registry.
run_tool() { nix_ run --inputs-from . "nixpkgs#$1" -- "${@:2}"; }

host_names() {
  nix_ eval --raw '.#nixosConfigurations' \
    --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)'
}

node_names() {
  nix_ eval --raw '.#deploy.nodes' \
    --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)'
}

# Emits the host list as JSON so CI can fan out one build job per host.
system_of() {
  nix_ eval --raw ".#nixosConfigurations.\"$1\".config.nixpkgs.hostPlatform.system"
}

# shellcheck disable=SC2016
list_hosts() {
  nix_ eval --json '.#nixosConfigurations' --apply \
    'c: map (n: { host = n; system = c.${n}.config.nixpkgs.hostPlatform.system; }) (builtins.attrNames c)'
}

eval_hosts() {
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    echo "  eval host $name"
    nix_ eval --raw ".#nixosConfigurations.\"$name\".config.system.build.toplevel.drvPath" >/dev/null
  done <<< "$(host_names)"
}

eval_nodes() {
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    echo "  eval node $name"
    nix_ eval --raw ".#deploy.nodes.\"$name\".hostname" >/dev/null
  done <<< "$(node_names)"
}

build_hosts() {
  local name names system
  if [ "$#" -gt 0 ]; then names="$1"; else names="$(host_names)"; fi
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    system=$(system_of "$name")
    echo "  build $name ($system)"
    nix_ build --no-link --print-build-logs ".#checks.$system.\"$name\""
  done <<< "$names"
}

drvpaths_at_ref() {
  local ref="$1"
  local wt
  wt="$(mktemp -d)"
  git worktree add --quiet --detach "$wt" "$ref"
  (
    cd "$wt"
    list_hosts | python3 -c 'import json,sys; [print(h["host"]) for h in json.load(sys.stdin)]' \
    | while IFS= read -r name; do
        drv=$(nix --extra-experimental-features 'nix-command flakes' eval --raw \
          ".#nixosConfigurations.\"$name\".config.system.build.toplevel.drvPath" 2>/dev/null) || drv="MISSING"
        printf '%s %s\n' "$name" "$drv"
      done
  )
  git worktree remove --force "$wt"
}

affected_hosts() {
  local base="$1"
  local before after changed

  before="$(drvpaths_at_ref "$base")"
  after="$(drvpaths_at_ref "HEAD")"

  changed="$(comm -13 <(sort <<< "$before") <(sort <<< "$after") | awk '{print $1}')"

  if [ -z "$changed" ]; then
    echo "[]"
    return
  fi

  list_hosts | python3 -c "
import json, sys
changed = set('''$changed'''.split())
hosts = json.load(sys.stdin)
print(json.dumps([h for h in hosts if h['host'] in changed]))
"
}

lint_nix() {
  run_tool deadnix --fail .
  run_tool statix check .
}

run_shellcheck() {
  local f complete fragments
  complete=()
  fragments=()
  # Shebang-less files are writeShellApplication fragments (Nix adds the shebang + vars): relax SC2148/SC2154.
  while IFS= read -r f; do
    if [ "$(head -c2 "$f")" = '#!' ]; then complete+=("$f"); else fragments+=("$f"); fi
  done < <(git ls-files '*.sh')
  if [ "${#complete[@]}" -gt 0 ]; then
    run_tool shellcheck "${complete[@]}"
  fi
  if [ "${#fragments[@]}" -gt 0 ]; then
    run_tool shellcheck --shell=bash -e SC2148,SC2154 "${fragments[@]}"
  fi
}

scan_secrets() {
  run_tool gitleaks detect --no-git --source . --redact --no-banner
}

scan_secrets_history() {
  run_tool gitleaks detect --source . --redact --no-banner
}

case "${1:-all}" in
  eval_hosts)      eval_hosts ;;
  eval_nodes)      eval_nodes ;;
  build)           build_hosts "${@:2}" ;;
  list)            list_hosts ;;
  affected)        affected_hosts "${2:?base ref required}" ;;
  lint)            lint_nix ;;
  shellcheck)      run_shellcheck ;;
  secrets)         scan_secrets ;;
  secrets-history) scan_secrets_history ;;
  all)             eval_hosts; lint_nix; run_shellcheck; scan_secrets ;;
  *)               echo "usage: $0 [eval|build [host]|list|lint|shellcheck|secrets|secrets-history|all]" >&2; exit 2 ;;
esac
