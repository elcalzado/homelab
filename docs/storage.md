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
│   └── movies/ tv/ music/ books/
└── library/
    └── movies/ tv/ music/ books/
```

## NAS

It's best to create some of the directories on the NAS instead of letting different hosts try to create them.

To create `torrents/` and `library/` run:
```bash
install -d -o root -g entertainment -m 770 /mnt/Storage/entertainment/torrents /mnt/Storage/entertainment/library
```