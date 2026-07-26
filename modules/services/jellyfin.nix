_:
{
  # Web UI on :8096
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    group = "entertainment";
  };

  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ "/mnt/entertainment" ];
}
