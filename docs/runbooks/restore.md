# Runbook: Restore a service from `backups`

**Goal:** put a service's database and config back from a dump on the NAS, either
the current one or a point-in-time snapshot.

Three things about this pipeline shape the procedure:

- The host's key is confined to `rrsync -wo`, so a host cannot read its own
  backups. Restores are driven from your workstation, which has SSH to both ends.
- The dumps are `0700 backups:backups`, so reading them on the NAS needs `sudo`.
- Ownership is not preserved. Every file on the NAS belongs to the `backups`
  user, so each restore ends with a `chown`.

> Never pipe `tar` straight from the NAS into a host. Both ends need `sudo`,
> `sudo` needs a TTY, and a TTY mangles a binary stream. Every step below writes
> the tarball to a file and moves it with `scp`.

---

## Step 1 — Pick the source

Current dump:
```bash
ssh -t guster@truenas.home.arpa 'sudo ls -la /mnt/blueberry/backups/<host>/<service>/'
```

A point-in-time copy. Snapshots are taken per host, so `.zfs` sits at the host
dataset root and the service is a directory inside it:
```bash
ssh -t guster@truenas.home.arpa 'sudo ls /mnt/blueberry/backups/<host>/.zfs/snapshot/'
```
Everything below works the same against a `.zfs/snapshot/<name>/<service>/` path.

> The newest dump is only as good as its last run. Check
> `/var/backup/<service>.last-success` on the host before trusting it, and
> `/var/backup/<service>.last-failure` for the opposite.

---

## Step 2 — Pull the dump to your workstation

```bash
ssh -t guster@truenas.home.arpa \
  'sudo tar -C /mnt/blueberry/backups/<host>/<service> -cf /tmp/<service>.tar . \
   && sudo chown guster /tmp/<service>.tar'

scp guster@truenas.home.arpa:/tmp/<service>.tar /tmp/
```

The `chown` is what lets `scp` fetch it without `sudo`.

---

## Step 3 — Verify the dump before touching the service

```bash
mkdir -p /tmp/verify && tar -C /tmp/verify -xf /tmp/<service>.tar && ls -la /tmp/verify
```

Then, by what the dataset holds:

| Kind | Check | Sound when |
|---|---|---|
| SQLite `.db` | `sqlite3 /tmp/verify/<db> "SELECT count(*) FROM sqlite_schema WHERE type='table'"` | a plausible table count, not `0` |
| SQLite `.db` | `sqlite3 /tmp/verify/<db> 'PRAGMA quick_check;'` | prints `ok` |
| Postgres `.sql` | `tail -c 4096 /tmp/verify/<db>.sql \| grep 'dump complete'` | matches |
| `mongodump/` | `find /tmp/verify/mongodump -mindepth 2 -name '*.bson' -not -path '*/admin/*'` | lists collections |

A plausible file listing plus that check means the dump is sound. Stop here if all
you wanted was to confirm the pipeline works.

---

## Step 4 — Stop the service

```bash
ssh -t guster@<host>.home.arpa 'sudo systemctl stop <unit>'
```

Leave it stopped until Step 6. Restoring underneath a running service corrupts
the database.

---

## Step 5 — Move the current state aside

Don't delete it!

```bash
ssh -t guster@<host>.home.arpa 'sudo mv <target> <target>.pre-restore'
```

---

## Step 6 — Extract, fix ownership, start

`<target>` is the directory on the host from the tables below. For a
single-target service, extract the whole tarball into a fresh one:

```bash
scp /tmp/<service>.tar guster@<host>.home.arpa:/tmp/

ssh -t guster@<host>.home.arpa '
  sudo install -d -m 0700 <target> &&
  sudo tar -C <target> -xf /tmp/<service>.tar &&
  sudo chown -R <owner> <target> &&
  sudo systemctl start <unit>'
```

For a **split-target** service the tarball's entries belong in different places,
so unpack to a scratch directory first and move each one:

```bash
ssh -t guster@<host>.home.arpa '
  mkdir -p /tmp/restore && tar -C /tmp/restore -xf /tmp/<service>.tar && ls -la /tmp/restore'
```
Then copy each entry to its own destination per the split table, `chown -R`, and
start the unit.

---

## Lookup tables

| Service | Host | Unit | Owner |
|---|---|---|---|
| jellyfin | jellyfin | `jellyfin` | `jellyfin:entertainment` |
| sonarr | servarr | `sonarr` | `sonarr:entertainment` |
| radarr | servarr | `radarr` | `radarr:entertainment` |
| prowlarr | servarr | `prowlarr` | systemd re-owns |
| bazarr | servarr | `bazarr` | `bazarr:entertainment` |
| seerr | servarr | `seerr` | systemd re-owns |
| qbittorrent | qbittorrent | `qbittorrent` | `qbittorrent:entertainment` |

`prowlarr` and `seerr` run under `DynamicUser`, so their uid is allocated fresh
at every start and systemd re-owns `StateDirectory` to match. Skip the `chown`.

Single-target — extract the tarball straight into the target:

| Service | Dataset holds | Target |
|---|---|---|
| sonarr | `sonarr.db`, `config.xml` | `/var/lib/sonarr/.config/NzbDrone` |
| radarr | `radarr.db`, `config.xml` | `/var/lib/radarr/.config/Radarr` |
| prowlarr | `prowlarr.db`, `config.xml` | `/var/lib/private/prowlarr` |

Split-target — copy each entry to its own destination, never the tree wholesale:

| Service | Dataset entry | Destination |
|---|---|---|
| bazarr | `bazarr.db` | `/var/lib/bazarr/db/` |
| bazarr | `config.yaml` | `/var/lib/bazarr/config/` |
| seerr | `db.sqlite3` | `/var/lib/private/seerr/db/` |
| seerr | `settings.json` | `/var/lib/private/seerr/` |
| jellyfin | `jellyfin.db` | `/var/lib/jellyfin/data/` |
| jellyfin | `config/` | `/var/lib/jellyfin/config/` |
| jellyfin | `plugins/` | `/var/lib/jellyfin/plugins/` |
| qbittorrent | `BT_backup/` | `/var/lib/qbittorrent/qBittorrent/data/` |
| qbittorrent | `categories.json` | `/var/lib/qbittorrent/qBittorrent/config/` |

---

## Omada is different

Its dump is the controller's own encrypted `.cfg` plus the keystore. There is no
file-level database restore.

1. Pull a `.cfg` out of `omada/omada/autobackup/` per Step 2.
2. Controller UI → Settings → Backup & Restore → Restore, and upload it.
3. Only `keystore/` and `omada.properties` are restored by file copy, to
   `/var/lib/omada/data/keystore` and
   `/opt/tplink/EAPController/properties/`, owned `omada:omada`.

> A `.cfg` only restores into the **same controller version** it came from. After
> a version bump, older files are for reference, not recovery.

`mongodump/` is the insurance against that.

---

## Immich is different

Pull and verify it per Steps 1-3, then land it and stop the service:

```bash
scp /tmp/immich.tar guster@immich.home.arpa:/tmp/

ssh -t guster@immich.home.arpa '
  mkdir -p /tmp/restore && tar -C /tmp/restore -xf /tmp/immich.tar &&
  sudo systemctl stop immich-server immich-machine-learning'
```

```bash
ssh -t guster@immich.home.arpa \
  'sudo -u postgres pg_dump --clean --if-exists --dbname=immich > /tmp/immich.pre-restore.sql &&
   tail -c 4096 /tmp/immich.pre-restore.sql | grep -q "dump complete" &&
   echo "pre-restore dump is sound"'
```

Then drop and recreate the database rather than replaying over it:

```bash
ssh -t guster@immich.home.arpa '
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "DROP DATABASE immich" &&
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE immich OWNER immich"'
```

Now replay it as `postgres`, not as `immich`, in a single transaction:

```bash
ssh -t guster@immich.home.arpa \
  'sudo -u postgres psql -d immich -v ON_ERROR_STOP=1 --single-transaction \
     -f /tmp/restore/immich.sql'
```

Then start it and confirm before trusting it:

```bash
ssh -t guster@immich.home.arpa 'sudo systemctl start immich-server immich-machine-learning'
```

Only once you have logged in and seen your library, discard the safety dump:

```bash
ssh -t guster@immich.home.arpa 'sudo rm -f /tmp/immich.pre-restore.sql'
```

---

## Step 7 — Verify, then clean up

Log in and confirm the data is actually there. Only then:

```bash
ssh -t guster@<host>.home.arpa 'sudo rm -rf <target>.pre-restore /tmp/<service>.tar'
ssh -t guster@truenas.home.arpa 'sudo rm -f /tmp/<service>.tar'
rm -rf /tmp/verify /tmp/<service>.tar
```

## Notes

- qBittorrent's `BT_backup` pairs each `.torrent` with its `.fastresume`. Restore
  the whole directory; a partial copy forces a recheck of the entire library.
- The dump is not a substitute for `vzdump`. It restores service state onto a
  working host, not a host.
