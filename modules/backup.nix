{ config, lib, pkgs, ... }:

let
  cfg = config.homelab.backup;

  stagingRoot = "/var/backup";
  knownHostsFile = "${stagingRoot}/known_hosts";

  absolutePath = lib.types.strMatching "/[^\n]*";

  shellList = xs: lib.escapeShellArg (lib.concatStringsSep "\n" xs);

  databaseParents = job: lib.unique (map builtins.dirOf job.databases);

  jobRunner = name: job: pkgs.writeShellApplication {
    name = "backup-${name}";
    runtimeInputs = with pkgs; [ coreutils findutils openssh rsync sqlite ];
    text = ''
      STAGE=${lib.escapeShellArg "${stagingRoot}/${name}"}
      MARKER=${lib.escapeShellArg "${stagingRoot}/${name}.last-success"}
      KNOWN_HOSTS=${lib.escapeShellArg knownHostsFile}
      STRICT_HOST_KEY=${if cfg.nas.hostKey == null then "accept-new" else "yes"}
      IDENTITY=${lib.escapeShellArg config.sops.secrets."backup/sshKey".path}
      REMOTE=${lib.escapeShellArg "${cfg.nas.user}@${cfg.nas.host}:${name}/"}
      MAX_DELETE=${toString cfg.maxDelete}
      MAX_AGE_HOURS=${lib.escapeShellArg (lib.optionalString (job.maxAge != null) (toString job.maxAge))}
      MAX_AGE_PATHS=${shellList (if job.maxAgePaths == [ ] then job.trees else job.maxAgePaths)}
      DATABASES=${shellList job.databases}
      FILES=${shellList job.files}
      TREES=${shellList job.trees}
      EXCLUDES=${shellList job.excludes}
      ${builtins.readFile ../scripts/backup/backup-job.sh}
    '';
  };

  failureRecorder = pkgs.writeShellApplication {
    name = "backup-record-failure";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      STAGING_ROOT=${lib.escapeShellArg stagingRoot}
      date --iso-8601=seconds > "$STAGING_ROOT/$1.last-failure"
    '';
  };
in
{
  options.homelab.backup = {
    nas = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "truenas.home.arpa";
        description = "Host holding the backup datasets.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "backups";
        description = "Account whose authorized_keys confines this host to `rrsync -wo`.";
      };

      hostKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHe/iN9fN5pBMxZWFDq0f2LkD10c92dvgA8ZkXbESrsd";
        description = ''
          SSH host public key, verified on every connection. Set to null to fall
          back to pinning whatever answers the first connection.
        '';
      };
    };

    maxDelete = lib.mkOption {
      type = lib.types.ints.positive;
      default = 64;
      description = "Ceiling on deletions rsync may perform on the remote per run.";
    };

    jobs = lib.mkOption {
      default = { };
      description = "Per-service dumps, each shipped to a dataset of the same name.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          at = lib.mkOption {
            type = lib.types.strMatching "[0-2][0-9]:[0-5][0-9]";
            description = "Daily slot, unique among this host's jobs.";
          };

          databases = lib.mkOption {
            type = lib.types.listOf absolutePath;
            default = [ ];
            description = "SQLite files copied through the online backup API, then verified.";
          };

          files = lib.mkOption {
            type = lib.types.listOf absolutePath;
            default = [ ];
            description = "Single files copied with their timestamps.";
          };

          trees = lib.mkOption {
            type = lib.types.listOf absolutePath;
            default = [ ];
            description = "Directories mirrored into staging.";
          };

          excludes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "rsync patterns withheld from every tree.";
          };

          maxAge = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Hours. Every path in `maxAgePaths` must hold a file newer than this.";
          };

          maxAgePaths = lib.mkOption {
            type = lib.types.listOf absolutePath;
            default = [ ];
            description = ''
              Paths the age check covers, catching a source that silently stopped
              being written. Defaults to every tree. Name them explicitly when a
              job also carries paths that are static or refreshed on their own.
            '';
          };
        };
      });
    };
  };

  config = lib.mkIf (cfg.jobs != { }) {
    sops.secrets."backup/sshKey" = { };

    programs.ssh.knownHosts = lib.optionalAttrs (cfg.nas.hostKey != null) {
      ${cfg.nas.host} = { publicKey = cfg.nas.hostKey; };
    };

    systemd = {
      tmpfiles.rules =
        [ "d ${stagingRoot} 0700 root root -" ]
        ++ lib.mapAttrsToList (name: _: "d ${stagingRoot}/${name} 0700 root root -") cfg.jobs;

      services = lib.mapAttrs'
        (name: job: lib.nameValuePair "backup-${name}" {
          description = "Back up ${name} to ${cfg.nas.host}";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          onFailure = [ "backup-failed@${name}.service" ];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe (jobRunner name job);
            UMask = "0077";
            ReadWritePaths = [ stagingRoot ] ++ databaseParents job;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            NoNewPrivileges = true;
            TimeoutStartSec = "1h";
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        })
        cfg.jobs
      // {
        "backup-failed@" = {
          description = "Record a failed backup of %i";

          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe failureRecorder} %i";
            UMask = "0077";
            ReadWritePaths = [ stagingRoot ];
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            NoNewPrivileges = true;
          };
        };
      };

      timers = lib.mapAttrs'
        (name: job: lib.nameValuePair "backup-${name}" {
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnCalendar = job.at;
            Persistent = true;
            AccuracySec = "1m";
            RandomizedDelaySec = "2m";
          };
        })
        cfg.jobs;
    };

    assertions = [
      {
        assertion =
          let
            slots = lib.mapAttrsToList (_: job: job.at) cfg.jobs;
          in
          lib.length (lib.unique slots) == lib.length slots;
        message = "homelab.backup.jobs on ${config.networking.hostName} share a slot";
      }
    ];
  };
}
