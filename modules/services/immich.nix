{ lib, ... }:

let
  mediaLocation = "/mnt/photos";
in
{
  # Web UI on :2283
  services.immich = {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
    group = "photos";
    inherit mediaLocation;
  };

  systemd = {
    tmpfiles.settings.immich.${mediaLocation}.e.mode = lib.mkForce "0770";

    services.immich-server = {
      unitConfig.RequiresMountsFor = [ mediaLocation ];
      serviceConfig.UMask = lib.mkForce "0007";
    };

    services.immich-machine-learning.serviceConfig.UMask = lib.mkForce "0007";
  };
}
