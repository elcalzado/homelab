_:
let
  klipperDir = "/var/lib/klipper";
  moonrakerDir = "/var/lib/moonraker";
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
      nginx.serverAliases = [ "mainsail.guster.xyz" ];
    };

    moonraker.enable = true;
    klipper.enable = true;
  };

  homelab.backup.jobs.mainsail = {
    at = "00:30";
    trees = [ klipperDir moonrakerDir ];
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
