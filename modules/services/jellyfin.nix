{ config, ... }:

let
  inherit (config.services.jellyfin) configDir dataDir;
in
{
  # Web UI on :8096
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    group = "entertainment";
  };

  homelab.backup.jobs.jellyfin = {
    at = "01:40";
    databases = [ { engine = "sqlite"; path = "${dataDir}/data/jellyfin.db"; } ];
    trees = [ configDir "${dataDir}/plugins" ];
    mayBeEmpty = [ "${dataDir}/plugins" ];
  };

  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ "/mnt/entertainment" ];
}
