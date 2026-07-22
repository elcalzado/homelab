{ lib, ... }:
{
  # Web UI on :7878
  services.radarr = {
    enable = true;
    openFirewall = true;
    group = "entertainment";
  };

  systemd.services.radarr = {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = [ "/mnt/entertainment" ];
  };
}
