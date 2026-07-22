{ config, ... }:
{
  services.recyclarr = {
    enable = true;
    schedule = "daily";

    configuration = {
      radarr.main = {
        base_url = "http://localhost:7878";
        api_key._secret = config.sops.secrets."recyclarr/radarr-api-key".path;
        quality_definition.type = "movie";
      };
      sonarr.main = {
        base_url = "http://localhost:8989";
        api_key._secret = config.sops.secrets."recyclarr/sonarr-api-key".path;
        quality_definition.type = "series";
      };
    };
  };

  sops.secrets."recyclarr/radarr-api-key" = { };
  sops.secrets."recyclarr/sonarr-api-key" = { };
}
