{ pkgs, ... }:
let
  dataDir = "/var/lib/velocity";
  package = pkgs.velocity;
in
{
  systemd.services.velocity = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${package}/bin/velocity";
      User = "velocity";
      Group = "velocity";
      ProtectSystem = "full";
      ProtectHome = true;
      NoNewPrivileges = true;
      ReadWritePaths = "${dataDir}";
      StateDirectory = "velocity";
      LogsDirectory = "velocity";
      WorkingDirectory = "${dataDir}";
      Restart = "on-abnormal";
    };
  };

  users = {
    groups.velocity = { };
    users.velocity = {
      group = "velocity";
      isSystemUser = true;
      home = "${dataDir}";
    };
  };

  networking.firewall.allowedTCPPorts = [ 25565 ];
}
