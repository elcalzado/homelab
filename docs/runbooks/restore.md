# Runbook: Restore a service from `backups`

**Goal:** put a service's database and config back from a dump on the NAS, either
the current one or a point-in-time snapshot.

Two things about this pipeline shape the procedure:

- The host's key is confined to `rrsync -wo`, so a host cannot read its own
  backups. Restores move the other direction and are driven from your
  workstation, which already has SSH to both ends. No standing NAS-to-host access
  is created.
- Ownership is not preserved. Every file on the NAS belongs to the `backups`
  user, so each restore ends with a `chown`.

---

## Step 1 — Pick the source

Current dump:
```bash
ssh truenas ls -la /mnt/blueberry/backups/<host>/<service>/
```

A point-in-time copy, from any snapshot listed by `zfs list -t snapshot`. Snapshots are taken per host, so `.zfs` sits at the host dataset root and the service is a directory inside it:
```bash
ssh truenas ls /mnt/blueberry/backups/<host>/.zfs/snapshot/
```
Everything below works the same against a `.zfs/snapshot/<name>/<service>/` path.

> The newest dump is only as good as its last run. Check
> `/var/backup/<service>.last-success` on the host before trusting it, and
> `/var/backup/<service>.last-failure` for the opposite.

---

## Step 2 — Stop the service

```bash
ssh guster@<host> sudo systemctl stop <unit>
```

Leave it stopped until the last step. Restoring underneath a running service
corrupts the database.

---

## Step 3 — Move the current state aside

Don't delete it!

```bash
ssh guster@<host> "sudo mv <target> <target>.pre-restore"
ssh guster@<host> "sudo install -d -m 0700 <target>"
```

---

## Step 4 — Copy the dump in

Piped through your workstation, so neither end needs new credentials:

```bash
ssh truenas "tar -C /mnt/blueberry/backups/<host>/<service> -cf - ." \
  | ssh guster@<host> "sudo tar -C <target> -xf -"
```

---

## Step 5 — Fix ownership, then start

```bash
ssh guster@<host> "sudo chown -R <owner> <target>"
ssh guster@<host> sudo systemctl start <unit>
```

---

## Lookup table

Databases and single files sit at the root of the dataset. Directories keep their
own name, so a service whose whole state directory is backed up appears one level
down.

| Service | Host | Unit | Owner |
|---|---|---|---|
| jellyfin | jellyfin | `jellyfin` | `jellyfin:entertainment` |
| sonarr | servarr | `sonarr` | `sonarr:entertainment` |
| radarr | servarr | `radarr` | `radarr:entertainment` |
| prowlarr | servarr | `prowlarr` | systemd re-owns |
| bazarr | servarr | `bazarr` | `bazarr:entertainment` |
| seerr | servarr | `seerr` | systemd re-owns |
| qbittorrent | qbittorrent | `qbittorrent` | `qbittorrent:entertainment` |

Single-target services:

| Service | Dataset holds | Target |
|---|---|---|
| sonarr | `sonarr.db`, `config.xml` | `/var/lib/sonarr/.config/NzbDrone` |
| radarr | `radarr.db`, `config.xml` | `/var/lib/radarr/.config/Radarr` |
| prowlarr | `prowlarr.db`, `config.xml` | `/var/lib/private/prowlarr` |
| seerr | `db.sqlite3`, `settings.json` | `/var/lib/private/seerr/db`, `/var/lib/private/seerr` |
| bazarr | `bazarr.db`, `config.yaml` | `/var/lib/bazarr/db`, `/var/lib/bazarr/config` |

Split-target services:

| Service | Dataset entry | Target |
|---|---|---|
| jellyfin | `jellyfin.db` | `/var/lib/jellyfin/data/` |
| jellyfin | `config/` | `/var/lib/jellyfin/config/` |
| jellyfin | `plugins/` | `/var/lib/jellyfin/plugins/` |
| qbittorrent | `BT_backup/` | `/var/lib/qbittorrent/qBittorrent/data/` |
| qbittorrent | `categories.json` | `/var/lib/qbittorrent/qBittorrent/config/` |

Jellyfin's `metadata/` and trickplay are not backed up, and neither is *arr
`MediaCover/`. All of it regenerates on a library scan.

---

## Omada is different

Its dump is the controller's own encrypted `.cfg` plus the keystore. There is no
file-level database restore.

1. Copy a `.cfg` out of `omada/omada/autobackup/` to your workstation.
2. Controller UI → Settings → Backup & Restore → Restore, and upload it.
3. Only `keystore/` and `omada.properties` are restored by file copy, to
   `/var/lib/omada/data/keystore` and
   `/opt/tplink/EAPController/properties/`, owned `omada:omada`.

> A `.cfg` only restores into the **same controller version** it came from. After
> a version bump, older files are for reference, not recovery.

`mongodump/` is the insurance against that: a version-independent BSON dump,
readable with `mongorestore` into a scratch mongod. It is not a supported way to
restore the controller — reach for it to read data a stale `.cfg` can no longer
restore, not to put a database back under a running Omada.

---

## Step 6 — Verify, then clean up

Log in and confirm the data is actually there. Only then:

```bash
ssh guster@<host> "sudo rm -rf <target>.pre-restore"
```

## Notes

- qBittorrent's `BT_backup` pairs each `.torrent` with its `.fastresume`. Restore
  the whole directory; a partial copy forces a recheck of the entire library.
- The dump is not a substitute for `vzdump`. It restores service state onto a
  working host, not a host.
