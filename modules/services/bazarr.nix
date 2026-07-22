{ lib, ... }:
{
  # Web UI on :6767
  services.bazarr = {
    enable = true;
    openFirewall = true;
    group = "entertainment";
  };

  systemd.services.bazarr = {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = [ "/mnt/entertainment" ];
  };
}
