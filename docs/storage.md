# Storage

Datasets are named and separated based on the data they hold and how important that data is. Avoid associating them with a tool that might be replaced in the future.

## Datasets

| Dataset | Holds | Consumers | Treatment |
|---|---|---|---|
| `photos` | Personal photos & videos | Immich | Irreplaceable → snapshots + offsite replication |
| `entertainment` | Movies / TV / Music / Books + download staging | *arr, qBittorrent, Jellyfin | Re-acquirable → light |
| `documents` | Documents / cloud files | nextcloud | Irreplaceable → snapshots + offsite replication |
| `backups` | DB dumps, configs, host backups | all | Staging → offsite replication |

## Rules

1. Databases live on the host that it belongs to. Periodic DB dumps are sent to `backups`.
2. `torrents/` and `library/` must stay together under the `entertainment` dataset. Otherwise, hardlinks and atomic moves won't work.
```bash
entertainment/
├── torrents/
│   └── temp/
└── library/
    └── movies/ shows/ songs/ books/
```
3. Dumps are pushed by each host over SSH, with the key confined to `rrsync -wo` over that host's subtree. Unprivileged LXC guests cannot mount NFS, and every platform uses the same mechanism.
4. Dumps overwrite in place. Snapshots are the retention.

One dataset per host, one directory per service inside it. rsync creates the service directory on first push, so adding a service needs nothing on the NAS.

```bash
backups/
├── omada/omada/
├── jellyfin/jellyfin/
├── servarr/{sonarr,radarr,prowlarr,bazarr,seerr}/
├── qbittorrent/qbittorrent/
└── immich/immich/
```

## Snapshots

Three recursive tasks each, on `backups` at 04:00 and `photos` at 05:00:

| Task | Schedule | Lifetime | Naming schema |
|---|---|---|---|
| daily | daily | 2 weeks | `auto-daily-%Y-%m-%d_%H-%M` |
| weekly | Sunday | 8 weeks | `auto-weekly-%Y-%m-%d_%H-%M` |
| monthly | on the 1st | 12 months | `auto-monthly-%Y-%m-%d_%H-%M` |

The tier prefix is what keeps the three from colliding when all of them fire on a Sunday the 1st.

`backups` must not be snapshotted while a job is running because writes are in-place, so a snapshot taken mid-push captures a torn file. The bound that has to hold is the worst case:

```
last slot + RandomizedDelaySec + TimeoutStartSec  <  snapshot time
02:50     + 2m                 + 1h               =  03:52  <  04:00
```

Timers are `Persistent`, so a host that was down through its slot runs the job on boot instead.

A job that fails partway still ships whatever it managed to stage, then exits non-zero without writing `.last-success`.

These properties apply to `backups` only. Set `recordsize` before the first sync.

| Property | Value | Reason |
|---|---|---|
| `recordsize` | `32K` | matches the ship step's `--block-size`, so one changed rsync block dirties one record |
| `compression` | `zstd` | the point of shipping dumps uncompressed; writes are nightly and niced, so ratio beats speed |

## Ownership

A numeric id is pinned only when something outside the host compares it. Everything else takes whatever NixOS allocates below 1000.

| Range | Holds | Assigned |
|---|---|---|
| 1000–1999 | People | `guster` 1000 |
| 2000–2999 | Management | |
| 3000-3999 | Media | `entertainment` 3000 |
| 4000-4999 | Data | `photos` 4000 |
| 9000-9999 | Public | |

## Directories

It's best to create some of the directories on the NAS instead of letting different hosts try to create them.

To create `torrents/` and `library/` run:
```bash
install -d -o root -g entertainment -m 770 /mnt/blueberry/entertainment/torrents /mnt/blueberry/entertainment/library
```

To create the `library` subdirectories:
```bash
install -d -o root -g entertainment -m 770 \
  /mnt/blueberry/entertainment/library/{movies,shows,songs,books}
```

The `backups` children are one dataset per host, owned `backups:backups` mode `0700`.

Then one `backups` user with a real shell and paste [truenas/authorized_keys](../truenas/authorized_keys) into `Credentials → Local Users → SSH Public Key`. Each line confines one host to its own subtree: 
- `restrict` drops PTY allocation and every kind of forwarding
- `command=` leaves no shell behind the key, and `rrsync` blocks `..` traversal
- `-wo` denies reads, so restores run from the NAS side. See [runbooks/restore.md](runbooks/restore.md)
