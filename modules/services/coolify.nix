{
  config,
  pkgs,
  ...
}:

let
  dataDir = "/data/coolify";

  composeMain = pkgs.fetchurl {
    url = "https://cdn.coollabs.io/coolify/docker-compose.yml";
    hash = "sha256-JTLukljhCtTobLPCtGwp/pMp9aDazg99pBB0T+7Ceb0=";
  };

  composeProd = pkgs.fetchurl {
    url = "https://cdn.coollabs.io/coolify/docker-compose.prod.yml";
    hash = "sha256-TNAOg+EX6Efm1r3+ZPKi+Vi7CZZWksUjD6kjGgMV+A8=";
  };
in
{
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };

  sops.secrets."coolify-env" = { };

  systemd.tmpfiles.rules = [
    "d /data/coolify        0700 9999 root -"
  ]
  ++ map (d: "d ${dataDir}/${d} 0700 9999 root -") [
    "source"
    "ssh"
    "ssh/keys"
    "ssh/mux"
    "applications"
    "databases"
    "backups"
    "services"
    "proxy"
    "proxy/dynamic"
    "webhooks-during-maintenance"
  ];

  systemd.services.coolify = {
    description = "Coolify control plane";
    wantedBy = [ "multi-user.target" ];
    after = [
      "docker.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    path = [
      config.virtualisation.docker.package
      pkgs.coreutils
    ];

    restartTriggers = [
      composeMain
      composeProd
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "${dataDir}/source";
      TimeoutStartSec = "10min";
    };

    script = ''
      install -m 0644 ${composeMain} docker-compose.yml
      install -m 0644 ${composeProd} docker-compose.prod.yml
      install -m 0600 ${config.sops.secrets."coolify-env".path} .env

      docker network inspect coolify >/dev/null 2>&1 \
        || docker network create --attachable coolify

      docker compose --env-file .env \
        -f docker-compose.yml -f docker-compose.prod.yml \
        up -d --remove-orphans
    '';

    preStop = ''
      docker compose --env-file .env \
        -f docker-compose.yml -f docker-compose.prod.yml \
        down
    '';
  };
}
