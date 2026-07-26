{ config, ... }:
{
  services.recyclarr = {
    enable = true;
    schedule = "daily";
    configuration = import ../../configs/recyclarr/config.nix {
      radarrApiKeyPath = config.sops.secrets."recyclarr/radarr-api-key".path;
      sonarrApiKeyPath = config.sops.secrets."recyclarr/sonarr-api-key".path;
    };
  };

  systemd.services.recyclarr = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  sops.secrets."recyclarr/radarr-api-key" = { };
  sops.secrets."recyclarr/sonarr-api-key" = { };
}
