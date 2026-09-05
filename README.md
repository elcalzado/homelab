# Homelab

NixOS homelab. Every machine is declared in `flake.nix` and built with:
```bash
nixos-rebuild switch --flake .#<output>
```

## Design
Host files (`hosts/`) are platform-agnostic and describe WHAT a machine runs.
The platform is layered on in `flake.nix`, so each host produces multiple outputs
from one definition.

## Layout
- `hosts/`    per-machine config (services + identity, no platform details)
- `modules/`  shared building blocks
  - `common.nix`   baseline for every host
  - `disk.nix`     disk set up
  - `lxc.nix`      LXC platform adapter
  - `vm.nix`       VM platform adapter
  - `pc.nix`       Bare metal platform adapter
  - `rpi.nix`      Raspberry Pi platform adapter
  - `services/`    one file per service
- `configs/`  per-service config templates (rendered by service modules)
- `scripts/`  per-service helper scripts (embedded into modules)
- `proxmox/`  Proxmox-host notes + container-creation scripts
- `truenas/`  NAS-side config the flake doesn't build
- `docs/`     network map, storage layout, and runbooks

## Hosts

| Name           | Address       | Platform |
|----------------|---------------|----------|
| omada          | `10.0.10.2`   | LXC      |
| qbittorrent    | `10.0.30.5`   | VM       |
| glance         | `10.0.30.6`   | LXC      |
| jellyfin       | `10.0.30.7`   | VM       |
| servarr        | `10.0.30.8`   | VM       |
| immich         | `10.0.30.9`   | VM       |
| portainer      | `10.0.30.10`  | LXC      |
| gatus          | `10.0.30.11`  | LXC      |
| runner         | `10.0.30.12`  | LXC      |
| builder        | `10.0.30.13`  | VM       |
| nextcloud      | `10.0.30.14`  | VM       |
| home-assistant | `10.0.30.15`  | LXC      |
