{ lib, ... }:
{
  # Web UI on :8989
  services.sonarr = {
    enable = true;
    openFirewall = true;
    group = "entertainment";
  };

  systemd.services.sonarr = {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = [ "/mnt/entertainment" ];
  };
}
