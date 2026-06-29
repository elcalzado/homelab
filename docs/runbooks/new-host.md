# Runbook: New host

**Goal:** get a new service running on a new machine, deployed from this repo.

A "host" here = one service on one machine. Provisioning it is three repo files
plus a platform-specific deploy. The repo work (Step 1) is identical for LXC and
VM; the deploy (Step 2) differs because an LXC template is already a running
NixOS, while a VM has to be installed onto a disk first.

Step 1 takes place on your **workstation**.
Step 2 takes place on **Proxmox**.

---

## Step 1 — Repo work

Make these three changes, then commit and push **before** touching the machine.

**1. Service module** — `modules/services/<name>.nix`
What the host runs. Platform-agnostic; reusable by any host.

**2. Host file** — `hosts/<name>/default.nix`
Identity + which modules it pulls in. No platform details.

```nix
{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/<name>.nix
  ];

  networking.hostName = "<name>";
  system.stateVersion = "26.05";    # set once, never change
}
```

**3. Flake entry** — add the host to `nixosConfigurations` in `flake.nix`:

```nix
nixosConfigurations =
  (mkHost "glance")
  // (mkHost "<name>");     # auto-creates outputs <name>-lxc and <name>-vm
```

**Commit + push:**

```bash
cd ~/homelab
git add .
git commit -m "<name>: new host"
git push
```

---

## Step 2 (LXC) — Provision + first deploy

### 2a. Create the container

Create `proxmox/containers/<name>.sh` using `proxmox/containers/_template.sh` then do the following commands in the shell:

```bash
pct start <ctid>
pct enter <ctid>

# Now inside of the lxc
source /etc/set-environment
passwd root # This will prompt you to enter a password
```

SSH will be set up when the build is finished using the public key(s) in common.nix

### 2b. First build

Build straight from GitHub:

  ```bash
  NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake github:elcalzado/homelab#<name>-lxc
  ```

This one build: fetches the repo, builds `<name>-lxc`, switches, **installs git**,
and **flips SSH to key-only**. Jump to Step 3.

---

## Step 2 (VM / baremetal) — Provision + first deploy

Work in progress...

---

## Step 3 — Steady state

```bash
ssh root@<host-ip>

# For first time on the machine, clone the repo locally:
cd /root && git clone https://github.com/elcalzado/homelab.git

# Every deploy after that:
cd /root/homelab && git pull && nixos-rebuild switch --flake .#<name>-lxc   # or .#<name>-vm
```

No more `--option` / `NIX_CONFIG` flag thanks to `common.nix` enabling flakes
permanently on the first build.

---

## Notes

- **stateVersion** is per-host and set once. Never bump it to "upgrade". More info in
  [updating.md](updating.md).
