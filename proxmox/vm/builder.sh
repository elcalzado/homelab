#!/usr/bin/env bash
set -euo pipefail

VMID="$(pvesh get /cluster/nextid)"

qm create "$VMID" \
  --name builder \
  --ostype l26 --machine q35 --bios ovmf \
  --efidisk0 "local-zfs:1,efitype=4m,pre-enrolled-keys=0" \
  --cpu host --cores 4 --sockets 1 \
  --memory 8192 --balloon 4096 \
  --scsihw virtio-scsi-pci --scsi0 "local-zfs:100" \
  --net0 "virtio,bridge=vmbr0v30" \
  --cdrom "local:iso/nixos-minimal-26.05.3869.95ca1e203c07-x86_64-linux.iso" \
  --boot order='scsi0;ide2' \
  --agent enabled=1 --onboot 1 \
&& qm set "$VMID" -serial0 socket
