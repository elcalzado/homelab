{ config, lib, ... }:

let
  inherit (config.services.radarr) dataDir;
in
{
  # Web UI on :7878
  services.radarr = {
    enable = true;
    openFirewall = true;
    group = "entertainment";
  };

  homelab.backup.jobs.radarr = {
    at = "02:10";
    databases = [ "${dataDir}/radarr.db" ];
    files = [ "${dataDir}/config.xml" ];
  };

  systemd.services.radarr = {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = [ "/mnt/entertainment" ];
  };
}
