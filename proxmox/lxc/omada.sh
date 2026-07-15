#!/usr/bin/env bash
set -euo pipefail

CTID="$(pvesh get /cluster/nextid)"

pct create "$CTID" "local:vztmpl/nixos-image-lxc-proxmox-26.05pre-git-x86_64-linux.tar.xz" \
  --hostname omada \
  --ostype nixos --arch amd64 \
  --unprivileged 1 --features nesting=1,keyctl=1 --cores 2 \
  --memory 4096 --swap 2048 \
  --rootfs "local-zfs:32" --storage "local-zfs" \
  --net0 "name=eth0,bridge=vmbr0,ip=10.0.10.2/27,gw=10.0.10.1" \
  --nameserver 10.0.10.1 \
  --onboot 1