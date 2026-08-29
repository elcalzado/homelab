#!/usr/bin/env bash
set -euo pipefail

CTID="$(pvesh get /cluster/nextid)"

pct create "$CTID" "local:vztmpl/nixos-image-lxc-proxmox-26.05pre-git-x86_64-linux.tar.xz" \
  --hostname home-assistant \
  --ostype nixos --arch amd64 \
  --unprivileged 1 --features nesting=1,keyctl=1 --cores 2 \
  --memory 4096 --swap 2048 \
  --rootfs "local-zfs:64" --storage "local-zfs" \
  --net0 "name=eth0,bridge=vmbr0v30,ip=10.0.30.15/26,gw=10.0.30.1" \
  --nameserver 10.0.30.1 \
  --onboot 1
