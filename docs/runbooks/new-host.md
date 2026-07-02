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

Jump to Step 3.

---

## Step 2 (VM / baremetal) — Provision + first deploy

A VM has no NixOS template to boot, so it must be installed onto its disk from
the NixOS ISO. The catch: the `-vm` flake output imports
`hosts/<name>/hardware-configuration.nix`, which doesn't exist until it's
generated *on the machine* — so the install and the repo cross paths once.

### 2a. Create the VM

Upload the NixOS **minimal ISO** to Proxmox, then create the VM with
`proxmox/vms/<name>.sh` (see `proxmox/vms/qbittorrent.sh` for the pattern —
UEFI/OVMF, virtio-scsi, bridge `vmbr0v30`). Start it; the empty disk falls
through to the ISO.

### 2b. Install NixOS onto the disk

In the VM console (booted off the ISO):

```bash
sudo -i
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart primary 512MiB 100%
mkfs.fat -F32 -n boot /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot && mount /dev/disk/by-label/boot /mnt/boot

nixos-generate-config --root /mnt
```

### 2c. Hand the hardware config to the repo

Copy `/mnt/etc/nixos/hardware-configuration.nix` off the VM into
`hosts/<name>/hardware-configuration.nix`.

### 2d. Bootstrap + first deploy

Install a minimal system so the VM boots with SSH, then switch to the flake:

```bash
nixos-install
reboot
```

After reboot (off the disk):

```bash
# place the sops age private key (for hosts that use secrets)
install -d -m700 /var/lib/sops-nix
# scp your key.txt to /var/lib/sops-nix/key.txt (mode 0600)

# build from GitHub
NIX_CONFIG="experimental-features = nix-command flakes" \
nixos-rebuild switch --flake github:elcalzado/homelab#<name>-vm
```

Jump to Step 3

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