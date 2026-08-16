# Homelab

NixOS homelab. Every machine is declared in `flake.nix` and built with:
```bash
nixos-rebuild switch --flake .#<output>
```

## Design
Host files (`hosts/`) are platform-agnostic and describe WHAT a machine runs.
The platform (LXC vs VM/baremetal) is layered on in `flake.nix`, so each host
produces two outputs from one definition:
- `<host>-amd64-lxc` — Proxmox LXC adapter
- `<host>-amd64-vm`  — VM/baremetal adapter + disko

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
- `truenas/`  NAS-side config the flake doesn't build
- `docs/`     network map, storage layout, and runbooks

## Hosts
| host   | runs             | platforms |
|--------|------------------|-----------|
| glance | [glance](https://github.com/glanceapp/glance) | any |
| qbittorrent | [qbittorrent-nox](https://github.com/qbittorrent/qBittorrent) + [wireguard](https://git.zx2c4.com/wireguard-linux/) + [nftables](https://git.netfilter.org/) + [clamav](https://github.com/Cisco-Talos/clamav) | vm |
| omada | [Omada Software Controller](https://www.tp-link.com/us/support/download/omada-software-controller/) + [mongodb](https://www.mongodb.com/) + [openjdk](https://openjdk.org/) + [jsvc](https://commons.apache.org/proper/commons-daemon/) | any |
| servarr | [prowlarr](https://github.com/Prowlarr/Prowlarr) + [sonarr](https://github.com/Sonarr/Sonarr) + [radarr](https://github.com/Radarr/Radarr) + [bazarr](https://github.com/morpheus65535/bazarr) + [recyclarr](https://github.com/recyclarr/recyclarr) + [seerr](https://github.com/seerr-team/seerr) | vm |
| jellyfin | [jellyfin](https://github.com/jellyfin/jellyfin) | vm |
| immich | [immich](https://github.com/immich-app/immich) | vm |
| portainer | [portainer](https://github.com/portainer/portainer) | any |
| gatus | [gatus](https://github.com/TwiN/gatus) | any |
| runner | [github-runner](https://github.com/actions/runner) + [deploy-rs](https://github.com/serokell/deploy-rs) | lxc |
| builder | remote nix builder (`x86_64-linux`, `aarch64-linux`) | vm |
| gamebox | [portainer edge agent](https://github.com/portainer/portainer) + game servers | vm |
