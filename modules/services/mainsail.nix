_: {
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

  networking.firewall.allowedTCPPorts = [ 80 ];
}
