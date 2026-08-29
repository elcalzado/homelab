{ config, ... }:

let
  mountDir = "/mnt/documents";
  dataDir = "${mountDir}/nextcloud";
in
{
  services.nextcloud = {
    enable = true;
    config = {
      adminpassFile = config.sops.secrets."webui/adminPass".path;
      adminuser = "guster";
      dbtype = "pgsql";
    };
    database.createLocally = true;
    datadir =  dataDir;
    hostName = "nextcloud.guster.xyz";
    settings.trusted_domains = [ "nextcloud.home.arpa" ];
    https = true;
  };

  users.users.nextcloud.extraGroups = [ "documents" ];

  sops.secrets."webui/adminPass" = { };

  homelab.backup.jobs.nextcloud = {
    at = "00:00";
    databases = [ { engine = "postgres"; name = "nextcloud"; } ];
  };

  systemd = {
    tmpfiles.rules = [
      "d ${dataDir} 0770 nextcloud nextcloud -"
    ];

    services = {
      phpfpm-nextcloud.unitConfig.RequiresMountsFor = [ mountDir ];
      nextcloud-setup.unitConfig.RequiresMountsFor = [ mountDir ];
      nextcloud-cron.unitConfig.RequiresMountsFor = [ mountDir ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
