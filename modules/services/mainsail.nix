_:
let
  dataDir = "/var/lib/moonraker";
in
{
  imports = [
    ../../configs/mainsail/klipper.nix
    ../../configs/mainsail/moonraker.nix
  ];

  services = {
    mainsail = {
      enable = true;
      hostName = "0.0.0.0";
    };

    moonraker.enable = true;
    klipper.enable = true;
  };

  users.groups.klipper = { };
  users.users.klipper = {
    isSystemUser = true;
    group = "klipper";
  };

  services.klipper.user = "klipper";
  services.klipper.group = "klipper";

  services.moonraker.group = "klipper";

  homelab.backup.jobs.mainsail = {
    at = "00:30";
    databases = [ { engine = "sqlite"; path = "${dataDir}/database/moonraker-sql.db"; } ];
    trees = [ "${dataDir}/gcodes" ];
    mayBeEmpty = [ "${dataDir}/gcodes" ];
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
