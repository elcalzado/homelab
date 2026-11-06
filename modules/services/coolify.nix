{
  config,
  lib,
  pkgs,
  ...
}:

let
  dataDir = "/data/coolify";
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

    unitConfig.ConditionPathExists = "!${dataDir}/source/.env";

    path = [
      config.virtualisation.docker.package
      pkgs.coreutils
      pkgs.curl
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "${dataDir}/source";
      TimeoutStartSec = "10min";
    };

    script = ''
      curl -fsSL -o docker-compose.yml https://cdn.coollabs.io/coolify/docker-compose.yml
      curl -fsSL -o docker-compose.prod.yml https://cdn.coollabs.io/coolify/docker-compose.prod.yml
      chmod 0644 docker-compose.yml docker-compose.prod.yml
      install -m 0600 ${config.sops.secrets."coolify-env".path} .env

      docker network inspect coolify >/dev/null 2>&1 \
        || docker network create --attachable coolify

      docker compose --env-file .env \
        -f docker-compose.yml -f docker-compose.prod.yml \
        up -d --remove-orphans
    '';
  };

  users = {
    groups.cooluser = { };
    users.cooluser = {
      isNormalUser = true;
      group = "cooluser";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtdAALxmQb8kE/NUjnQJoAy4LSjt4lHS6KFywVNSYfj"
      ];
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "cooluser" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = [
    (lib.hiPrio pkgs.procps)
  ];

  homelab.backup.jobs.coolify = {
    at = "00:50";
    trees = [ "${dataDir}/backups" ];
  };
}
