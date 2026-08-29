{ config, ... }:
{
  # Web UI on :8123
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "analytics"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"
      "isal"
    ];
    config = {
      default_config = {};
      homeassistant = {
        latitude = "!secret latitude";
        longitude = "!secret longitude";
        elevation = "!secret elevation";
        unit_system = "metric";
        time_zone = "America/New_York";
      };
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = [ "10.0.30.1" ];
      };
    };
    extraPackages = ps: with ps; [ psycopg2 ];
    config.recorder.db_url = "postgresql://@/hass";
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "hass" ];
    ensureUsers = [{
      name = "hass";
      ensureDBOwnership = true;
    }];
  };

  homelab.backup.jobs.home-assistant = {
    at = "00:10";
    databases = [ { engine = "postgres"; name = "hass"; } ];
  };

  networking.firewall.allowedTCPPorts = [
    config.services.home-assistant.config.http.server_port
  ];

  sops.secrets = {
    "config-secrets/latitude" = { };
    "config-secrets/longitude" = { };
    "config-secrets/elevation" = { };
  };

  sops.templates."config-secrets.yaml" = {
    content = ''
        latitude: ${config.sops.placeholder."config-secrets/latitude"}
        longitude: ${config.sops.placeholder."config-secrets/longitude"}
        elevation: ${config.sops.placeholder."config-secrets/elevation"}
    '';
    owner = "hass";
    group = "hass";
    path = "/var/lib/hass/secrets.yaml";
  };
}
