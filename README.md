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
  - `services/`    one file per service
- `configs/`  per-service config templates (rendered by service modules)
- `scripts/`  per-service helper scripts (embedded into modules)
- `proxmox/`  Proxmox-host notes + container-creation scripts
- `truenas/`  NAS-side config the flake doesn't build
- `docs/`     network map, storage layout, and runbooks
