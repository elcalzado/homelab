# Runbook: Update / upgrade (`flake.lock`)

`flake.lock` pins every input to an exact commit. **Nothing moves until you
update it**.

All of this happens on your **workstation**, in `homelab` repo root. Each update is a
normal git commit: reviewable, and revertible if it breaks something.

---

## When to update

- **Security patches / newer package versions**
- **A specific newer version you need** (upstream bugfix, new feature).
- **Bumping to a new NixOS release**
- **After adding or changing an input** in `flake.nix`.

---

## Update everything

```bash
cd ~/homelab
nix flake update                 # re-pin ALL inputs to their latest
git add flake.lock
git commit -m "flake.lock: update inputs"
git push
```

## Update one input only (usually preferred)

```bash
nix flake update nixpkgs         # re-pin ONLY nixpkgs; all other inputs stay frozen
```

Commit + push the same way.

---

## Bump to a new NixOS release

1. Edit `flake.nix`: `nixpkgs.url = "github:NixOS/nixpkgs/nixos-XX.YY";`
2. `nix flake update nixpkgs`
3. Review, then commit **`flake.nix` and `flake.lock` together**, and push.

> Do **not** change `system.stateVersion` when bumping releases. It records the
> release a host was *first installed* with and controls stateful-data defaults;
> leave it alone.

---

## Apply an update to your machines

Updating the lock doesn't touch any running machine. Roll out the changes
per host, over SSH, at whatever pace works:

```bash
cd /root/homelab && git pull && nixos-rebuild switch --flake .#<output>
```

Hosts move **independently** so pull/rebuild only the ones you want on the new
pins.

---

## If an update breaks something

Fastest recovery: revert the lock commit and rebuild. More info in
[rollback.md](rollback.md).

```bash
# on workstation
git revert <lock-commit> && git push

# then on the affected host:
cd /root/homelab && git pull && nixos-rebuild switch --flake .#<output>
```

---

## Notes

- `flake.nix` changes and the matching `flake.lock` change go in the **same
  commit**. The two should never be in disagreement.
- Updates are always deliberate. There is no "auto-update".
