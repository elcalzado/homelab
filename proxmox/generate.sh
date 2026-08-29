#!/usr/bin/env bash
# Generate a reusable Proxmox provisioning script for a NixOS host.
# Usage: generate.sh <host> <lxc|vm>  ->  writes proxmox/<platform>/<host>.sh
set -euo pipefail

HOST="${1:-}"
PLATFORM="${2:-}"

if [[ -z "$HOST" || "$PLATFORM" != "lxc" && "$PLATFORM" != "vm" ]]; then
  echo "usage: $0 <host> <lxc|vm>" >&2
  exit 1
fi

# prompt (to stderr) with a default; echo the chosen value on stdout
ask() { local IN; read -rp "$1 [$2]: " IN || true; printf '%s' "${IN:-$2}"; }

OUT_DIR="$(dirname "$0")/$PLATFORM"
OUT="$OUT_DIR/$HOST.sh"
mkdir -p "$OUT_DIR"
if [[ -e "$OUT" ]]; then
  read -rp "$OUT exists — overwrite? [y/N]: " YN || true
  [[ "$YN" == [yY] ]] || { echo "aborted" >&2; exit 1; }
fi

STORAGE="$(ask "storage" "local-zfs")"
BRIDGE="$(ask "bridge" "vmbr0v30")"

if [[ "$PLATFORM" == "vm" ]]; then
  CORES="$(ask "CPUs (cores)" "2")"
  SOCKETS="$(ask "sockets" "1")"
  MEMORY="$(ask "RAM (MB)" "4096")"
  BALLOON="$(ask "balloon (MB, 0=off)" "0")"
  DISK="$(ask "disk (GB)" "16")"
  ISO="$(ask "install ISO" "local:iso/nixos-minimal-26.05.8538.d57af924f160-x86_64-linux.iso")"

  cat > "$OUT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

VMID="\$(pvesh get /cluster/nextid)"

qm create "\$VMID" \\
  --name $HOST \\
  --ostype l26 --machine q35 --bios ovmf \\
  --efidisk0 "$STORAGE:1,efitype=4m,pre-enrolled-keys=0" \\
  --cpu host --cores $CORES --sockets $SOCKETS \\
  --memory $MEMORY --balloon $BALLOON \\
  --scsihw virtio-scsi-pci --scsi0 "$STORAGE:$DISK" \\
  --net0 "virtio,bridge=$BRIDGE" \\
  --cdrom "$ISO" \\
  --boot order='scsi0;ide2' \\
  --agent enabled=1 --onboot 1 \\
&& qm set "\$VMID" -serial0 socket
EOF

else
  TEMPLATE="$(ask "template (pveam list local)" "local:vztmpl/nixos-image-lxc-proxmox-26.05pre-git-x86_64-linux.tar.xz")"
  CORES="$(ask "CPUs (cores, blank=all host)" "")"
  MEMORY="$(ask "RAM (MB)" "2048")"
  SWAP="$(ask "swap (MB)" "1024")"
  DISK="$(ask "rootfs (GB)" "16")"
  IP="$(ask "IP address" "")"
  CIDR="$(ask "subnet prefix" "26")"
  GATEWAY="$(ask "gateway" "10.0.30.1")"
  NS="$(ask "nameserver" "10.0.30.1")"
  [[ -n "$IP" ]] || { echo "IP address is required for lxc" >&2; exit 1; }

  # blank CORES => all host cores (omit the flag)
  CORES_ARG=""; [[ -n "$CORES" ]] && CORES_ARG="--cores $CORES"

  cat > "$OUT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

CTID="\$(pvesh get /cluster/nextid)"

pct create "\$CTID" "$TEMPLATE" \\
  --hostname $HOST \\
  --ostype nixos --arch amd64 \\
  --unprivileged 1 --features nesting=1,keyctl=1 $CORES_ARG \\
  --memory $MEMORY --swap $SWAP \\
  --rootfs "$STORAGE:$DISK" --storage "$STORAGE" \\
  --net0 "name=eth0,bridge=$BRIDGE,ip=$IP/$CIDR,gw=$GATEWAY" \\
  --nameserver $NS \\
  --onboot 1
EOF
fi

chmod +x "$OUT"
echo "wrote $OUT" >&2
