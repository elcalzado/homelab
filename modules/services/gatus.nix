{
  config,
  lib,
  pkgs,
  ...
}:

let
  reporterUser = config.homelab.backup.reporter.user;

  publicKeyOf =
    line:
    let
      matched = builtins.match ".* (ssh-[a-z0-9-]+ [A-Za-z0-9+/=]+ [^ ]+)" line;
    in
    if matched == null then
      throw "truenas/authorized_keys holds a line with no public key: ${line}"
    else
      lib.head matched;

  backupPublicKeys = map publicKeyOf (
    lib.filter (line: line != "") (
      lib.splitString "\n" (builtins.readFile ../../truenas/authorized_keys)
    )
  );

  reportReceiver = pkgs.writeShellApplication {
    name = "backup-report-receive";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      read -r success job message <<< "$SSH_ORIGINAL_COMMAND"

      if [[ ! "$success" =~ ^(true|false)$ || ! "$job" =~ ^[a-z0-9-]+$ ]]; then
        echo "expected: <true|false> <job> [message]" >&2
        exit 2
      fi

      url="http://127.0.0.1:${toString config.services.gatus.settings.web.port}/api/v1/endpoints/backups_$job/external?success=$success"
      if [[ -n "$message" ]]; then
        url+="&error=$(jq -rn --arg v "$message" '$v|@uri')"
      fi

      curl -fsS -X POST \
        -H "Authorization: Bearer $(cat ${
          lib.escapeShellArg config.sops.secrets."backup/gatusToken".path
        })" \
        "$url"
    '';
  };

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

  backupAlerts = [
    {
      type = "matrix";
      failure-threshold = 1;
      success-threshold = 1;
      send-on-resolved = true;
    }
  ];

  web =
    {
      name,
      group,
      url,
      insecure ? false,
    }:
    {
      inherit
        name
        group
        url
        interval
        alerts
        ;
      conditions = [
        "[STATUS] < 400"
        "[RESPONSE_TIME] < ${toString slowMillis}"
      ];
    }
    // lib.optionalAttrs insecure { client.insecure = true; };

  listening =
    {
      name,
      group,
      host,
      port,
    }:
    {
      inherit
        name
        group
        interval
        alerts
        ;
      url = "tcp://${host}:${toString port}";
      conditions = [ "[CONNECTED] == true" ];
    };

  backupJobs = import ../../configs/gatus/backup-jobs.nix;

  externalBackup = name: {
    inherit name;
    group = "backups";
    token = "\${BACKUP_GATUS_TOKEN}";
    heartbeat = {
      interval = "25h";
    };
    alerts = backupAlerts;
  };
in
{
  sops = {
    secrets = {
      "matrix/accessToken" = { };
      "matrix/roomId" = { };
      "backup/gatusToken" = {
        owner = reporterUser;
      };
    };

    templates."gatus.env".content = ''
      MATRIX_ACCESS_TOKEN=${config.sops.placeholder."matrix/accessToken"}
      MATRIX_ROOM_ID="'${config.sops.placeholder."matrix/roomId"}'"
      BACKUP_GATUS_TOKEN=${config.sops.placeholder."backup/gatusToken"}
    '';
  };

  users = {
    groups.${reporterUser} = { };

    users.${reporterUser} = {
      isSystemUser = true;
      group = reporterUser;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = map (
        key: ''restrict,command="${lib.getExe reportReceiver}" ${key}''
      ) backupPublicKeys;
    };
  };

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
        (web {
          name = "jellyfin";
          group = "media";
          url = "http://jellyfin.home.arpa:8096/health";
        })
        (web {
          name = "sonarr";
          group = "media";
          url = "http://servarr.home.arpa:8989/ping";
        })
        (web {
          name = "radarr";
          group = "media";
          url = "http://servarr.home.arpa:7878/ping";
        })
        (web {
          name = "prowlarr";
          group = "media";
          url = "http://servarr.home.arpa:9696/ping";
        })
        (web {
          name = "bazarr";
          group = "media";
          url = "http://servarr.home.arpa:6767";
        })
        (web {
          name = "seerr";
          group = "media";
          url = "http://servarr.home.arpa:5055";
        })
        (web {
          name = "qbittorrent";
          group = "media";
          url = "http://qbittorrent.home.arpa:8080";
        })

        (web {
          name = "immich";
          group = "photos";
          url = "http://immich.home.arpa:2283/api/server/ping";
        })

        (web {
          name = "nextcloud";
          group = "documents";
          url = "https://nextcloud.home.arpa";
        })

        (web {
          name = "glance";
          group = "management";
          url = "http://glance.home.arpa:8080";
        })
        (web {
          name = "portainer";
          group = "management";
          url = "https://portainer.home.arpa:9443";
          insecure = true;
        })
        (web {
          name = "home-assistant";
          group = "management";
          url = "http://hass.home.arpa:8123";
        })

        (web {
          name = "pve1";
          group = "infrastructure";
          url = "https://pve1.home.arpa:8006";
          insecure = true;
        })
        (web {
          name = "pve2";
          group = "infrastructure";
          url = "https://pve2.home.arpa:8006";
          insecure = true;
        })
        (web {
          name = "pve3";
          group = "infrastructure";
          url = "https://pve3.home.arpa:8006";
          insecure = true;
        })

        (web {
          name = "truenas";
          group = "infrastructure";
          url = "https://truenas.home.arpa";
          insecure = true;
        })
        (listening {
          name = "runner";
          group = "infrastructure";
          host = "runner.home.arpa";
          port = 22;
        })
        (listening {
          name = "builder";
          group = "infrastructure";
          host = "builder.home.arpa";
          port = 22;
        })
      ];

      external-endpoints = map externalBackup backupJobs;
    };
  };

  homelab.backup.jobs.gatus = {
    at = "00:40";
    databases = [
      {
        engine = "sqlite";
        path = "/var/lib/private/gatus/data.db";
      }
    ];
  };
}
