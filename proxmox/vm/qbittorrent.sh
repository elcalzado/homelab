#!/usr/bin/env bash
set -euo pipefail

vmid="$(pvesh get /cluster/nextid)"
storage="local-zfs"
bridge="vmbr0v30"
iso="local:iso/nixos-minimal-26.05-x86_64-linux.iso"

qm create "${vmid}" \
  --name qbittorrent \
  --ostype l26 \
  --machine q35 \
  --bios ovmf \
  --efidisk0 ${storage}:1,efitype=4m,pre-enrolled-keys=0 \
  --cpu host --cores 2 --sockets 1 \
  --memory 4096 --balloon 0 \
  --scsihw virtio-scsi-pci \
  --scsi0 ${storage}:16 \
  --net0 virtio,bridge=${bridge} \
  --cdrom "${iso}" \
  --boot order='scsi0;ide2' \
  --agent enabled=1 \
  --onboot 1
