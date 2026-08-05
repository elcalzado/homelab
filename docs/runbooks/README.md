# Runbooks

Operational procedures for this homelab. Each file is a self-contained
checklist that can be followed without re-deriving anything.

| Runbook | Use it when |
|---------|-------------|
| [new-host.md](new-host.md) | Spinning up a new service on a new LXC or VM |
| [arr-stack.md](arr-stack.md) | Wiring the *arr apps + qBittorrent + Jellyfin into a pipeline |
| [updating.md](updating.md) | Updating `flake.lock` / upgrading packages |
| [rollback.md](rollback.md) | A rebuild broke something and you need to recover |
| [restore.md](restore.md) | A service lost its database or config and needs a dump from `backups` |

## The model

- **Workstation** = home of the repo. All editing + `git` happens here.
- **New machine** = only ever *pulls* the repo and runs `nixos-rebuild` on
  itself.
- **Outputs are named `<host>-lxc` and `<host>-vm`.** The suffix is the
  platform selector; the host file underneath is platform-agnostic.
