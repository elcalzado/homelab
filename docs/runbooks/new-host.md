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
  // (mkHost nixpkgs "<name>" [ "amd64-lxc" "amd64-vm" ]);   # one output per target
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

```bash
passwd root                               # temp root password

# sops hosts: age key first
install -d -m700 /var/lib/sops-nix
cat > /var/lib/sops-nix/key.txt           # paste key, then Ctrl-D
chmod 600 /var/lib/sops-nix/key.txt

# swap the template's key-only sshd for a throwaway permissive one (absolute path required)
systemctl stop sshd.socket sshd.service 2>/dev/null; pkill -x sshd 2>/dev/null
ssh-keygen -A
/run/current-system/sw/bin/sshd -o PermitRootLogin=yes -o PasswordAuthentication=yes
```

From your workstation, builds on `builder`, activates in the container:

```bash
ssh-copy-id root@<host-ip>

nix run --extra-experimental-features 'nix-command flakes' \
  nixpkgs#nixos-rebuild-ng -- switch \
  --flake .#<name>-amd64-lxc \
  --target-host root@<host-ip>
```

Back in the container:

```bash
pkill -x sshd
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
  --flake .#<name>-amd64-vm                                 \
  --build-on remote                                         \
  --extra-files /tmp/extra                                  \
  root@10.0.30.<x>
```

**Bare metal:** identical, plus set `disko.devices.disk.main.device` in
`hosts/<name>/default.nix` if the disk isn't `/dev/sda` (e.g. `/dev/nvme0n1`).

Jump to Step 3

---

## Step 3 — Add it to the deploy pipeline

**1.** Add a node to `deploy.nodes` in `flake.nix`:

```nix
<name> = mkNode "<name>-amd64-vm";     # or -amd64-lxc
```

**2.** Add `<name>` to the `host` dropdown in `.github/workflows/deploy.yml`
and `.github/workflows/rollback.yml`.

**3.** Add the host to `docs/network.md` and the README table.

Commit and push, then deploy from Actions → **deploy** → `dry-activate`,
then `switch`.

---

## Step 4 — Steady state

Actions → **deploy** → pick host → `switch`. See [updating.md](updating.md).

...or...

From workstation (builds on builder):
```bash
nix run --extra-experimental-features 'nix-command flakes' \
  nixpkgs#nixos-rebuild-ng -- switch \
  --flake .#<name>-<arch>-<platform> \
  --target-host guster@<host>.home.arpa --sudo --ask-sudo-password
```

...or...

From workstation (builds on host):
```bash
rsync -a --delete --exclude='.git' ./ guster@<host>.home.arpa:~/homelab/ 
ssh -t guster@<host>.home.arpa 'cd ~/homelab && sudo nixos-rebuild switch --flake .#<host>-<arch>-<platform>'
```


---

## Notes

- **stateVersion** is per-host and set once. Never bump it to "upgrade". More info in
  [updating.md](updating.md).
- Steps 1-2 are the only manual `nixos-rebuild` a host ever needs. Everything
  after goes through Actions.
- The workstation offloads Linux builds to `builder` via `/etc/nix/machines`. 