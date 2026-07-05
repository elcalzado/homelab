#!/usr/bin/env bash
set -euo pipefail

ctid="$(pvesh get /cluster/nextid)"
ctt="local:vztmpl/nixos-image-lxc-proxmox-26.05pre-git-x86_64-linux.tar.xz"
cts="local-zfs"
ctb="vmbr0v30"
ctip="10.0.30.6/26"
ctgw="10.0.30.1"
ctns="10.0.30.1"

pct create "${ctid}" "${ctt}" \
  --hostname=glance \
  --ostype=nixos \
  --unprivileged=1 --features nesting=1,keyctl=1 \
  --net0 name=eth0,bridge=${ctb},ip=${ctip},gw=${ctgw} \
  --nameserver ${ctns} \
  --arch=amd64 --swap=1024 --memory=2048 \
  --rootfs ${cts}:16 \
  --storage=${cts} \
  --onboot=1
