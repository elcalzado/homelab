# Homelab

NixOS homelab. Every machine is declared in `flake.nix` and built with:
```bash
nixos-rebuild switch --flake .#<output>
```

## Design
Host files (`hosts/`) are platform-agnostic and describe WHAT a machine runs.
The platform (LXC vs VM/baremetal) is layered on in `flake.nix`, so each host
produces two outputs from one definition:
- `<host>-lxc` — Proxmox LXC adapter
- `<host>-vm`  — VM/baremetal adapter + disko

## Layout
- `hosts/`    per-machine config (services + identity, no platform details)
- `modules/`  shared building blocks
  - `common.nix`   baseline for every host
  - `disk.nix`     disk set up for VM/baremetal hosts
  - `lxc.nix`      Proxmox-LXC platform adapter
  - `vm.nix`       VM/baremetal platform adapter
  - `services/`    one file per service
- `configs/`  per-service config templates (rendered by service modules)
- `scripts/`  per-service helper scripts (embedded into modules)
- `proxmox/`  Proxmox-host notes + container-creation scripts
- `docs/`     network map, storage layout, and runbooks

## Hosts
| host   | runs             | deploy                                            | platforms |
|--------|------------------|---------------------------------------------------|-----------|
| glance | [glance](https://github.com/glanceapp/glance) | `nixos-rebuild switch --flake .#glance-<vm\|lxc>` | any |
| qbittorrent | [qbittorrent-nox](https://github.com/qbittorrent/qBittorrent) + [wireguard](https://git.zx2c4.com/wireguard-linux/) + [nftables](https://git.netfilter.org/) + [clamav](https://github.com/Cisco-Talos/clamav) | `nixos-rebuild switch --flake .#qbittorrent-vm` | vm |
| omada | [Omada Software Controller](https://www.tp-link.com/us/support/download/omada-software-controller/) + [mongodb](https://www.mongodb.com/) + [openjdk](https://openjdk.org/) + [jsvc](https://commons.apache.org/proper/commons-daemon/) | `nixos-rebuild switch --flake .#omada-<vm\|lxc>` | any |
| servarr | [prowlarr](https://github.com/Prowlarr/Prowlarr) + [sonarr](https://github.com/Sonarr/Sonarr) + [radarr](https://github.com/Radarr/Radarr) + [bazarr](https://github.com/morpheus65535/bazarr) + [recyclarr](https://github.com/recyclarr/recyclarr) + [seerr](https://github.com/seerr-team/seerr) | `nixos-rebuild switch --flake .#servarr-vm` | vm |
| jellyfin | [jellyfin](https://github.com/jellyfin/jellyfin) | `nixos-rebuild switch --flake .#jellyfin-vm` | vm |
