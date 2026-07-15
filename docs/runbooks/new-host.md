# Runbook: New host

**Goal:** get a new service running on a new machine, deployed from this repo.

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

Generate the container script with `bash proxmox/generate.sh <name> lxc`; it writes
`proxmox/lxc/<name>.sh`. Run that on the Proxmox host to `pct create` the container, then:

```bash
pct start <ctid>
pct enter <ctid>

# Now inside of the lxc
source /etc/set-environment
```

SSH will be set up when the build is finished using the public key(s) in common.nix

### 2b. First build

For hosts that use sops, install the age key first

```bash
install -d -m700 /var/lib/sops-nix
cat > /var/lib/sops-nix/key.txt           # paste the key contents, then Ctrl-D
chmod 600 /var/lib/sops-nix/key.txt
```

Build straight from GitHub:

```bash
NIX_CONFIG="experimental-features = nix-command flakes" \
nixos-rebuild switch --flake github:elcalzado/homelab#<name>-lxc
```

Jump to Step 3.

---

## Step 2 (VM / baremetal) — Provision + first deploy

### 2a. Create the VM

Upload the NixOS **minimal ISO** to Proxmox, then create the VM with
`proxmox/vm/<name>.sh` (using `proxmox/generate.sh <name> vm`)

### 2b. Make the installer reachable (one manual step)

VLAN 30 has no DHCP, so give the live installer an address and a way in, in the
VM console:

```bash
ip addr add 10.0.30.<x>/26 dev ens18      # any free IP; check the NIC with `ip link`
ip route add default via 10.0.30.1
echo "nameserver 10.0.30.1" | tee /etc/resolv.conf
passwd root                               # set a temp root password
```

### 2c. Install from your workstation

For hosts that use sops, hand the age key to the installer so it's present on
first boot:

```bash
mkdir -p /tmp/extra/var/lib/sops-nix && cp /path/to/key.txt /tmp/extra/var/lib/sops-nix/key.txt
```

The following command partitions the disk, installs the whole config, and reboots:

```bash
nix run --extra-experimental-features "nix-command flakes"  \
  github:nix-community/nixos-anywhere --                    \
  --flake .#<name>-vm                                       \
  --extra-files /tmp/extra                                  \
  root@10.0.30.<x>
```

**Bare metal:** identical, plus set `disko.devices.disk.main.device` in
`hosts/<name>/default.nix` if the disk isn't `/dev/sda` (e.g. `/dev/nvme0n1`).

Jump to Step 3

---

## Step 3 — Steady state

```bash
ssh guster@<host-ip>

# For first time on the machine, clone the repo locally:
cd ~ && git clone https://github.com/elcalzado/homelab.git

# Every deploy after that:
cd ~/homelab && git pull && nixos-rebuild switch --flake .#<name>-lxc   # or .#<name>-vm
```

---

## Notes

- **stateVersion** is per-host and set once. Never bump it to "upgrade". More info in
  [updating.md](updating.md). 