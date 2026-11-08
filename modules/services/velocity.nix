{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  dataDir = "/var/lib/velocity";
  overridesFile = ../../configs/velocity/velocity-overrides.toml;

  mergeConfig = pkgs.writeShellApplication {
    name = "velocity-merge-config";
    runtimeInputs = [
      pkgs.yj
      pkgs.jq
    ];
    text = ''
      DATA_DIR=${dataDir}
      OVERRIDES_FILE=${overridesFile}
      ${builtins.readFile ../../scripts/velocity/merge-config.sh}
    '';
  };

  package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.velocity;
in
{
  systemd.services.velocity = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${package}/bin/velocity";
      ExecStartPre = lib.getExe mergeConfig;
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

  sops = {
    secrets."velocity/forwardingSecret" = { };

    templates."forwarding.secret" = {
      content = "${config.sops.placeholder."velocity/forwardingSecret"}";
      owner = "velocity";
      group = "velocity";
      path = "${dataDir}/forwarding.secret";
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
