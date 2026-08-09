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
    echo "  eval $name"
    nix_ eval --raw ".#nixosConfigurations.\"$name\".config.system.build.toplevel.drvPath" >/dev/null
  done <<< "$(host_names)"
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
  eval)            eval_hosts ;;
  build)           build_hosts "${@:2}" ;;
  list)            list_hosts ;;
  lint)            lint_nix ;;
  shellcheck)      run_shellcheck ;;
  secrets)         scan_secrets ;;
  secrets-history) scan_secrets_history ;;
  all)             eval_hosts; lint_nix; run_shellcheck; scan_secrets ;;
  *)               echo "usage: $0 [eval|build [host]|list|lint|shellcheck|secrets|secrets-history|all]" >&2; exit 2 ;;
esac
