{ config, lib, ... }:

let
  inherit (config.services.bazarr) dataDir;
in
{
  # Web UI on :6767
  services.bazarr = {
    enable = true;
    openFirewall = true;
    group = "entertainment";
  };

  homelab.backup.jobs.bazarr = {
    at = "02:30";
    databases = [ "${dataDir}/db/bazarr.db" ];
    files = [ "${dataDir}/config/config.yaml" ];
  };

  systemd.services.bazarr = {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = [ "/mnt/entertainment" ];
  };
}
