{ config, lib, ... }:

let
  interval = "1m";
  slowMillis = 3000;
  matrixServerUrl = "https://matrix-client.matrix.org";

  alerts = [
    {
      type = "matrix";
      failure-threshold = 3;
      success-threshold = 2;
      send-on-resolved = true;
    }
  ];

  web =
    { name, group, url, insecure ? false }:
    {
      inherit name group url interval alerts;
      conditions = [ "[STATUS] < 400" "[RESPONSE_TIME] < ${toString slowMillis}" ];
    }
    // lib.optionalAttrs insecure { client.insecure = true; };

  listening =
    { name, group, host, port }:
    {
      inherit name group interval alerts;
      url = "tcp://${host}:${toString port}";
      conditions = [ "[CONNECTED] == true" ];
    };
in
{
  sops = {
    secrets = {
      "matrix/accessToken" = { };
      "matrix/roomId" = { };
    };

    templates."gatus.env".content = ''
      MATRIX_ACCESS_TOKEN=${config.sops.placeholder."matrix/accessToken"}
      MATRIX_ROOM_ID="'${config.sops.placeholder."matrix/roomId"}'"
    '';
  };

  # Web UI on :8080
  services.gatus = {
    enable = true;
    openFirewall = true;
    environmentFile = config.sops.templates."gatus.env".path;

    settings = {
      web.port = 8080;
      ui.title = "homelab";

      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      alerting.matrix = {
        server-url = matrixServerUrl;
        access-token = "\${MATRIX_ACCESS_TOKEN}";
        internal-room-id = "\${MATRIX_ROOM_ID}";
      };

      endpoints = [
        (web { name = "jellyfin"; group = "media"; url = "http://jellyfin.home.arpa:8096/health"; })
        (web { name = "sonarr"; group = "media"; url = "http://servarr.home.arpa:8989/ping"; })
        (web { name = "radarr"; group = "media"; url = "http://servarr.home.arpa:7878/ping"; })
        (web { name = "prowlarr"; group = "media"; url = "http://servarr.home.arpa:9696/ping"; })
        (web { name = "bazarr"; group = "media"; url = "http://servarr.home.arpa:6767"; })
        (web { name = "seerr"; group = "media"; url = "http://servarr.home.arpa:5055"; })
        (web { name = "qbittorrent"; group = "media"; url = "http://qbittorrent.home.arpa:8080"; })

        (web { name = "immich"; group = "photos"; url = "http://immich.home.arpa:2283/api/server/ping"; })
        
        (web { name = "glance"; group = "management"; url = "http://glance.home.arpa:8080"; })
        (web { name = "portainer"; group = "management"; url = "https://portainer.home.arpa:9443"; insecure = true; })

        (web { name = "truenas"; group = "infrastructure"; url = "https://truenas.home.arpa"; insecure = true; })
        (listening { name = "backups"; group = "infrastructure"; host = "truenas.home.arpa"; port = 22; })
        (listening { name = "runner"; group = "infrastructure"; host = "runner.home.arpa"; port = 22; })
        (listening { name = "builder"; group = "infrastructure"; host = "builder.home.arpa"; port = 22; })
      ];
    };
  };

  homelab.backup.jobs.gatus = {
    at = "00:40";
    databases = [ { engine = "sqlite"; path = "/var/lib/private/gatus/data.db"; } ];
  };
}
