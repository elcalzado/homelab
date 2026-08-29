#!/usr/bin/env bash
set -euo pipefail

VMID="$(pvesh get /cluster/nextid)"

qm create "$VMID" \
  --name nextcloud \
  --ostype l26 --machine q35 --bios ovmf \
  --efidisk0 "local-zfs:1,efitype=4m,pre-enrolled-keys=0" \
  --cpu host --cores 1 --sockets 1 \
  --memory 1024 --balloon 0 \
  --scsihw virtio-scsi-pci --scsi0 "local-zfs:16" \
  --net0 "virtio,bridge=vmbr0v30" \
  --cdrom "local:iso/nixos-minimal-26.05.8538.d57af924f160-x86_64-linux.iso" \
  --boot order='scsi0;ide2' \
  --agent enabled=1 --onboot 1 \
&& qm set "$VMID" -serial0 socket
