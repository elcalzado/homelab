{ config, lib, ... }:

let
  inherit (config.services.sonarr) dataDir;
in
{
  # Web UI on :8989
  services.sonarr = {
    enable = true;
    openFirewall = true;
    group = "entertainment";
  };

  homelab.backup.jobs.sonarr = {
    at = "02:00";
    databases = [ "${dataDir}/sonarr.db" ];
    files = [ "${dataDir}/config.xml" ];
  };

  systemd.services.sonarr = {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = [ "/mnt/entertainment" ];
  };
}
