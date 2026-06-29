# Homelab

NixOS homelab. Every machine is declared in `flake.nix` and built with
`nixos-rebuild switch --flake .#<output>`.

## Design
Host files (`hosts/`) are platform-agnostic and describe WHAT a machine runs.
The platform (LXC vs VM/baremetal) is layered on in `flake.nix`, so each host
produces two outputs from one definition:
- `<host>-lxc` — Proxmox LXC adapter
- `<host>-vm`  — VM/baremetal adapter + that machine's generated hardware config

## Layout
- `hosts/`    per-machine config (services + identity, no platform details)
- `modules/`  shared building blocks
  - `common.nix`   baseline for every host
  - `lxc.nix`      Proxmox-LXC platform adapter
  - `vm.nix`       VM/baremetal platform adapter
  - `services/`    one file per service
- `proxmox/`  Proxmox-host notes + container-creation scripts
- `docs/`     network map

## Hosts
| host   | runs             | deploy                                            |
|--------|------------------|---------------------------------------------------|
| glance | Glance dashboard | `nixos-rebuild switch --flake .#glance-<vm\|lxc>` |
