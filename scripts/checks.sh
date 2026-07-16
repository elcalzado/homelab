#!/usr/bin/env bash
# Repo checks shared by CI (.github/workflows/ci.yml) and the git pre-commit hook
# (scripts/git-hooks/pre-commit), so the two don't drift.
#
# Usage: scripts/checks.sh [eval|lint|shellcheck|secrets|secrets-history|all]   (default: all)
#
# Everything runs through nix, so the only prerequisite is Nix with flakes.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

nix_() { nix --extra-experimental-features 'nix-command flakes' "$@"; }

# Run a nixpkgs tool from the flake's pinned nixpkgs (--inputs-from), not the floating registry.
run_tool() { nix_ run --inputs-from . "nixpkgs#$1" -- "${@:2}"; }

eval_hosts() {
  local names name
  names=$(nix_ eval --raw '.#nixosConfigurations' \
    --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)')
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    echo "  eval $name"
    nix_ eval --raw ".#nixosConfigurations.\"$name\".config.system.build.toplevel.drvPath" >/dev/null
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
  lint)            lint_nix ;;
  shellcheck)      run_shellcheck ;;
  secrets)         scan_secrets ;;
  secrets-history) scan_secrets_history ;;
  all)             eval_hosts; lint_nix; run_shellcheck; scan_secrets ;;
  *)               echo "usage: $0 [eval|lint|shellcheck|secrets|secrets-history|all]" >&2; exit 2 ;;
esac
