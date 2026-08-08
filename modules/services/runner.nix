{ config, lib, pkgs, ... }:

let
  cfg = config.homelab.runner;
in
{
  options.homelab.runner = {
    url = lib.mkOption {
      type = lib.types.str;
      description = "Repository the runner registers against.";
    };

    builder = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "Address of the machine that realises every derivation.";
      };

      hostKey = lib.mkOption {
        type = lib.types.str;
        description = "The builder's SSH host public key, pinned so the first connection is verified.";
      };

      maxJobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
        description = "Derivations the builder runs concurrently.";
      };
    };
  };

  config = {
    sops.secrets = {
      "github/runnerToken" = { };
      "builder/sshKey" = { };
    };

    services.github-runners.homelab = {
      enable = true;
      inherit (cfg) url;
      tokenFile = config.sops.secrets."github/runnerToken".path;
      ephemeral = true;
      user = "github-runner";
      group = "github-runner";
      extraLabels = [ "homelab" ];
      extraPackages = with pkgs; [ git openssh nix ];
    };

    users.users.github-runner = {
      isSystemUser = true;
      group = "github-runner";
      home = "/var/lib/github-runner";
    };

    users.groups.github-runner = { };

    programs.ssh.knownHosts.${cfg.builder.host}.publicKey = cfg.builder.hostKey;

    nix = {
      distributedBuilds = true;

      settings = {
        max-jobs = 0;
        builders-use-substitutes = true;
        trusted-users = [ "github-runner" ];
      };

      buildMachines = [
        {
          hostName = cfg.builder.host;
          sshUser = "nixbuilder";
          sshKey = config.sops.secrets."builder/sshKey".path;
          systems = [ "x86_64-linux" "aarch64-linux" ];
          inherit (cfg.builder) maxJobs;
          speedFactor = 1;
          supportedFeatures = [ "big-parallel" "kvm" "nixos-test" ];
        }
      ];
    };
  };
}
