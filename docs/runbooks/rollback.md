# Runbook: Roll back a broken change

You have **two independent layers** of safety:

- **git**: the source of truth. Undo a bad commit, rebuild, done.
- **NixOS generations**: every `switch` keeps the previous built systems
  around, so you can reactivate an older one instantly, even with no repo access.

Pick based on the situation below.

---

## Case 1 — Bad config you pushed, machine still on the old system

You haven't switched yet (or the build failed before switching). Just fix the
source. On your **workstation**:

```bash
cd ~/homelab
git revert <bad-commit>          # or: git revert HEAD
git push
```

Then on the affected host:

```bash
cd ~/homelab && git pull && nixos-rebuild switch --flake .#<output>
```

Reverting a **`flake.lock`** commit specifically undoes a bad *update* and
restores the previous pins.

---

## Case 2 — Already switched, the new system is broken

The new generation is live and misbehaving. Get back up now, on the machine itself:

```bash
nixos-rebuild switch --rollback
```

This reactivates the previous generation immediately. Once you're back up, fix
the real cause in the repo on your workstation (Case 1), then redeploy.

---

## Inspect / pick a specific generation

```bash
nixos-rebuild list-generations
# universal fallback:
nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Activate a specific generation `N`:

```bash
/nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch
```

> **LXC note:** there's no boot menu like a VM has, but `--rollback` and
> generation switching work exactly the same through the shell.

---

## Recommended order when something breaks

1. **Broke during build / not yet switched** → fix forward, or `git revert`.
2. **Switched and broken** → `nixos-rebuild switch --rollback` to restore
   service immediately.
3. **Then** fix the cause in the repo (workstation), push, `git pull` + rebuild.

---

## Notes

 - Old generations are *what makes rollback possible*. `nix-collect-garbage -d`
deletes them. Don't run it right after a risky change you might still need to
undo.
