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
└── qbittorrent/qbittorrent/
```

## Snapshots

| Property | Value | Reason |
|---|---|---|
| `recordsize` | `32K` | matches the ship step's `--block-size`, so one changed rsync block dirties one record |
| `compression` | `zstd` | the point of shipping dumps uncompressed; writes are nightly and niced, so ratio beats speed |

Set `recordsize` before the first sync.

Three recursive tasks on `backups`:

| Task | Schedule | Lifetime | Naming schema |
|---|---|---|---|
| daily | 04:00 daily | 2 weeks | `auto-daily-%Y-%m-%d_%H-%M` |
| weekly | 04:00 Sunday | 8 weeks | `auto-weekly-%Y-%m-%d_%H-%M` |
| monthly | 04:00 on the 1st | 12 months | `auto-monthly-%Y-%m-%d_%H-%M` |

The tier prefix is what keeps the three from colliding when all of them fire on a Sunday the 1st.

The 04:00 window must stay clear of every job. Writes are in-place, so a snapshot taken mid-push captures a torn file.

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
