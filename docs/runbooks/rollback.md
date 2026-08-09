# Runbook: Roll back a broken change

Two independent layers:

- **git** — the source of truth. Revert, redeploy.
- **NixOS generations** — every `switch` keeps the previous system, reactivated
  with no repo access.

---

## Case 0 — deploy-rs already rolled it back

`magicRollback` reverts automatically when the host stops answering after
activation. The job log ends with a rollback line and the workflow fails.

Nothing to do on the host. Fix the cause in the repo.

---

## Case 1 — Switched and broken, host still reachable

Actions → **rollback** → pick host → Run workflow.

Or directly:

```bash
ssh -t guster@<host>.home.arpa 'sudo nixos-rebuild switch --rollback'
```

---

## Case 2 — Bad commit, machine still on the old system

```bash
cd ~/homelab
git revert <bad-commit>
git push
```

Then deploy per [updating.md](updating.md).

Reverting a **`flake.lock`** commit undoes a bad *update* and restores the
previous pins.

---

## Case 3 — Host unreachable

LXC:

```bash
pct enter <ctid>
nixos-rebuild switch --rollback
```

VM: Proxmox console → pick an older generation at the boot menu.

---

## Inspect / pick a specific generation

```bash
nixos-rebuild list-generations
nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Activate generation `N`:

```bash
/nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch
```

---

## The builder is down and the runner won't rebuild

`runner` sets `max-jobs = 0`, so it cannot build without `builder`:

```bash
sudo nixos-rebuild switch --flake .#runner-amd64-lxc --option max-jobs 4
```

---

## Notes

- `nix-collect-garbage -d` deletes old generations. Don't run it right after a
  risky change.
