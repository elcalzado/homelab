# Runbook: *arr stack wiring

**Goal:** wire the `servarr` apps + qBittorrent + Jellyfin into a working
request → download → import → play pipeline. Assumes the hosts are deployed
([new-host.md](new-host.md)) and the `entertainment` dataset exists
([storage.md](../storage.md)).

All \*arr apps run on `servarr` and reach each other over `localhost`. Grab each
app's key from Settings → General → Security → API Key.

| App | Host:Port |
|---|---|
| Prowlarr | localhost:9696 |
| Radarr | localhost:7878 |
| Sonarr | localhost:8989 |
| Bazarr | localhost:6767 |
| Seerr | localhost:5055 |
| FlareSolverr | localhost:8191 |
| qBittorrent | qbittorrent.home.arpa:8080 |
| Jellyfin | jellyfin.home.arpa:8096 |

---

## 1. Jellyfin
- Dashboard → Libraries → add the following:
  - Movies: `/mnt/entertainment/library/movies`
  - Shows: `/mnt/entertainment/library/shows`.
- Per library, disable: `Real-time Monitoring`, `Metadata savers (Nfo)`, `Save
  artwork into media folders`, `Save trickplay images next to media`.
- Dashboard → API Keys → create one for Radarr and Sonarr.

## 2. Prowlarr
1. Indexers → add indexers. Set `Download Link = Magnet` and `Apps Minimum
   Seeders` as needed.
2. Settings → Indexers → add `FlareSolverr` + tag `flaresolverr` then tag
   Cloudflare-walled indexers with `flaresolverr`.
3. Settings → Apps → Sync Profiles → edit `Standard`: `Enable RSS = off`.
4. Settings → Apps → add Radarr and Sonarr + their API keys.

## 3. Radarr/Sonarr
- Settings → Media Management → add root folder: `/mnt/entertainment/library/<movies|shows>`.
- Settings → Download Clients → add `qBittorrent`: host, port, WebUI API key,
  category `radarr` / `sonarr`.
- Settings → Connect → add `Emby / Jellyfin`: host, port, API key.

> Profiles are managed by recyclarr ([config.nix](../../configs/recyclarr/config.nix)):
> Radarr `SQP-1 (2160p)`, Sonarr `WEB-2160p` + `Anime`. Deploy, then
> `systemctl start recyclarr.service`.

## 4. Bazarr
- Settings → Sonarr / Radarr → add each host, port, API key.
- Settings → Languages → insert desired languages in filter.
- Settings → Languages → create a profile, set as default for Series + Movies.
- Settings → Providers → add one.

## 5. Seerr
- Settings → Jellyfin → enable the Movies + Shows libraries and run a full scan.
- Services → Radarr: host, port, API key
  - Quality Profile `SQP-1 (2160p)`
  - Root Folder `/mnt/entertainment/library/movies`
- Services → Sonarr: host, port, API key
  - Quality Profile `WEB-2160p`
  - Root Folder `/mnt/entertainment/library/shows`
  - Anime Quality Profile `Anime`
  - Anime Root Folder `/mnt/entertainment/library/shows`
- For both, check: `Enable Scan`, `Automatic Search`, and `Tag Requests`.

## 6. Verify
Request a movie + a show in Seerr → grabbed in the \*arr → downloading in
qBittorrent → hardlink-imported into `library/` → Jellyfin scan fires → seerr
flips to Available.
