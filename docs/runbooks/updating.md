# Runbook: Update / upgrade (`flake.lock`)

`flake.lock` pins every input to an exact commit. Updating the lock changes no
running machine — deploying does.

---

## 1. Bump the lock

```bash
cd ~/homelab
git switch -c update-inputs

nix flake update                 # all inputs
nix flake update nixpkgs         # or one only

git commit -am "flake.lock: update inputs"
git push -u origin update-inputs
```

Open a PR. CI builds every host; merge only when green.

## Bump to a new NixOS release

1. Edit `flake.nix`: `nixpkgs.url = "github:NixOS/nixpkgs/nixos-XX.YY";`
2. `nix flake update nixpkgs`
3. Commit `flake.nix` and `flake.lock` together.

> Never change `system.stateVersion` when bumping releases.

---

## 2. Deploy

Actions → **deploy** → pick host → `dry-activate` → Run workflow.
Approve when the `production` environment prompts.

Review the `-- package changes --` diff in the log, then repeat with `switch`.

One host at a time; hosts move independently.

### From the workstation instead

```bash
cd ~/homelab
./scripts/deploy.sh <node> dry-activate
./scripts/deploy.sh <node> switch
```

Node names are the keys of `deploy.nodes` in `flake.nix`.

---

## 3. If it breaks

See [rollback.md](rollback.md).

```bash
git revert <lock-commit> && git push
```

Then deploy the reverted lock.

---

## Notes

- `flake.nix` and its `flake.lock` change go in the **same commit**.
- Only `nixpkgs-unstable` moves immich; `nixpkgs` moves every other host.
- To hold one package back, overlay it from a second pinned input rather than
  splitting the channel.
