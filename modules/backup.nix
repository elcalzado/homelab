{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homelab.backup;

  stagingRoot = "/var/backup";
  knownHostsFile = "${stagingRoot}/known_hosts";

  hardenedOneshot = {
    Type = "oneshot";
    UMask = "0077";
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
  };

  absolutePath = lib.types.strMatching "/[^\n]*";

  shellList = xs: lib.escapeShellArg (lib.concatStringsSep "\n" xs);

  engineSpecs = {
    sqlite = {
      requiredFields = [ "path" ];
      unusedFields = [
        "name"
        "port"
      ];
      dumpLine =
        db:
        lib.concatStringsSep "\t" [
          "sqlite"
          db.path
          (baseNameOf db.path)
        ];
      tools = [ pkgs.sqlite ];
    };
    postgres = {
      requiredFields = [ "name" ];
      unusedFields = [
        "path"
        "port"
      ];
      dumpLine =
        db:
        lib.concatStringsSep "\t" [
          "postgres"
          db.name
          "${db.name}.sql"
        ];
      tools = [
        config.services.postgresql.package
        pkgs.util-linux
      ];
    };
    mongodb = {
      requiredFields = [
        "name"
        "port"
      ];
      unusedFields = [ "path" ];
      dumpLine =
        db:
        lib.concatStringsSep "\t" [
          "mongodb"
          (toString db.port)
          db.name
        ];
      tools = [ pkgs.mongodb-tools ];
    };
  };

  databaseEntry = lib.types.submodule {
    options = {
      engine = lib.mkOption {
        type = lib.types.enum (lib.attrNames engineSpecs);
        description = "Which dump tool handles this database. Always stated.";
      };

      path = lib.mkOption {
        type = lib.types.nullOr absolutePath;
        default = null;
        description = "sqlite: the database file to copy.";
      };

      name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "postgres: the database to dump. mongodb: the staged directory name.";
      };

      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "mongodb: the port mongod listens on.";
      };
    };
  };

  treeAssertions =
    jobName: job:
    map (path: {
      assertion = lib.elem path job.trees;
      message = "homelab.backup.jobs.${jobName}.mayBeEmpty names ${path}, which is not one of its trees";
    }) job.mayBeEmpty;

  databaseAssertions =
    jobName: job:
    lib.imap0 (
      index: db:
      let
        spec = engineSpecs.${db.engine};
        missing = lib.filter (field: db.${field} == null) spec.requiredFields;
        ignored = lib.filter (field: db.${field} != null) spec.unusedFields;
        located = "homelab.backup.jobs.${jobName}.databases.[${toString index}] (${db.engine})";
      in
      {
        assertion = missing == [ ] && ignored == [ ];
        message = lib.concatStringsSep " " (
          [ "${located}:" ]
          ++ lib.optional (missing != [ ]) "must set ${lib.concatStringsSep ", " missing}."
          ++ lib.optional (ignored != [ ]) "ignores ${lib.concatStringsSep ", " ignored}, so remove it."
        );
      }
    ) job.databases;

  dumpLine = db: engineSpecs.${db.engine}.dumpLine db;

  sqliteParents =
    job:
    lib.unique (
      map (db: builtins.dirOf db.path) (lib.filter (db: db.engine == "sqlite") job.databases)
    );

  engineTools =
    job:
    lib.concatMap (engine: engineSpecs.${engine}.tools) (
      lib.unique (map (db: db.engine) job.databases)
    );

  maxAgePathsFor = job: if job.maxAgePaths == [ ] then job.trees else job.maxAgePaths;

  strictHostKeyCheckingFor = hostKey: if hostKey == null then "accept-new" else "yes";

  jobRunner =
    name: job:
    pkgs.writeShellApplication {
      name = "backup-${name}";
      runtimeInputs =
        (with pkgs; [
          coreutils
          findutils
          openssh
          rsync
        ])
        ++ engineTools job;
      text = ''
        STAGE=${lib.escapeShellArg "${stagingRoot}/${name}"}
        MARKER=${lib.escapeShellArg "${stagingRoot}/${name}.last-success"}
        KNOWN_HOSTS=${lib.escapeShellArg knownHostsFile}
        STRICT_HOST_KEY=${strictHostKeyCheckingFor cfg.nas.hostKey}
        IDENTITY=${lib.escapeShellArg config.sops.secrets."backup/sshKey".path}
        REMOTE=${lib.escapeShellArg "${cfg.nas.user}@${cfg.nas.host}:${name}/"}
        MAX_DELETE=${toString cfg.maxDelete}
        MAX_AGE_HOURS=${lib.escapeShellArg (lib.optionalString (job.maxAge != null) (toString job.maxAge))}
        MAX_AGE_PATHS=${shellList (maxAgePathsFor job)}
        MAY_BE_EMPTY=${shellList job.mayBeEmpty}
        DATABASES=${shellList (map dumpLine job.databases)}
        FILES=${shellList job.files}
        TREES=${shellList job.trees}
        EXCLUDES=${shellList job.excludes}
        ${builtins.readFile ../scripts/backup/backup-job.sh}
      '';
    };

  mkResultRecorder =
    outcome:
    pkgs.writeShellApplication {
      name = "backup-record-${outcome}";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        STAGING_ROOT=${lib.escapeShellArg stagingRoot}
        date --iso-8601=seconds > "$STAGING_ROOT/$1.last-${outcome}"
      '';
    };

  failureRecorder = mkResultRecorder "failure";
  successRecorder = mkResultRecorder "success";

  reportScript = pkgs.writeShellApplication {
    name = "backup-report";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      ssh \
        -i ${lib.escapeShellArg config.sops.secrets."backup/sshKey".path} \
        -o UserKnownHostsFile=${lib.escapeShellArg knownHostsFile} \
        -o StrictHostKeyChecking=${strictHostKeyCheckingFor cfg.reporter.hostKey} \
        ${lib.escapeShellArg "${cfg.reporter.user}@${cfg.reporter.host}"} \
        "$*"
    '';
  };

  mkStagingDirRule = path: "d ${path} 0700 root root -";

  mkOutcomeService =
    {
      outcome,
      recorder,
      reportArgs,
    }:
    {
      description = "Record and announce a ${outcome} backup of %i";
      serviceConfig = hardenedOneshot // {
        ExecStart = [
          "${lib.getExe recorder} %i"
          "${lib.getExe reportScript} ${reportArgs}"
        ];
        ReadWritePaths = [ stagingRoot ];
      };
    };

  hasDuplicateTimeSlot =
    jobs:
    let
      slots = lib.mapAttrsToList (_: job: job.at) jobs;
    in
    lib.length (lib.unique slots) != lib.length slots;
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

    reporter = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "gatus.home.arpa";
        description = "Host receiving backup outcomes over SSH.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "backup-report";
        description = "Account whose authorized_keys forces every backup key into the reporter.";
      };

      hostKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          SSH host public key, verified on every connection. Null pins whatever
          answers the first connection.
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
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            at = lib.mkOption {
              type = lib.types.strMatching "([01][0-9]|2[0-3]):[0-5][0-9]";
              description = "Daily slot, unique among this host's jobs.";
            };

            databases = lib.mkOption {
              type = lib.types.listOf databaseEntry;
              default = [ ];
              description = ''
                Databases dumped and verified before shipping. Every entry names
                its engine; an empty list means the job carries no database.
              '';
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

            mayBeEmpty = lib.mkOption {
              type = lib.types.listOf absolutePath;
              default = [ ];
              description = ''
                Trees allowed to stage without a single file. Every other tree
                staging empty is a failure, because an empty mirror would
                otherwise propagate through `--delete-after` and prune the copy
                already on the NAS.
              '';
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
        }
      );
    };
  };

  config = lib.mkIf (cfg.jobs != { }) {
    sops.secrets."backup/sshKey" = { };

    programs.ssh.knownHosts =
      lib.optionalAttrs (cfg.nas.hostKey != null) {
        ${cfg.nas.host} = {
          publicKey = cfg.nas.hostKey;
        };
      }
      // lib.optionalAttrs (cfg.reporter.hostKey != null) {
        ${cfg.reporter.host} = {
          publicKey = cfg.reporter.hostKey;
        };
      };

    systemd = {
      tmpfiles.rules = [
        (mkStagingDirRule stagingRoot)
      ]
      ++ lib.mapAttrsToList (name: _: mkStagingDirRule "${stagingRoot}/${name}") cfg.jobs;

      services =
        lib.mapAttrs' (
          name: job:
          lib.nameValuePair "backup-${name}" {
            description = "Back up ${name} to ${cfg.nas.host}";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            onSuccess = [ "backup-success@${name}.service" ];
            onFailure = [ "backup-failed@${name}.service" ];

            serviceConfig = hardenedOneshot // {
              ExecStart = lib.getExe (jobRunner name job);
              ReadWritePaths = [ stagingRoot ] ++ sqliteParents job;
              TimeoutStartSec = "1h";
              Nice = 10;
              IOSchedulingClass = "idle";
            };
          }
        ) cfg.jobs
        // {
          "backup-success@" = mkOutcomeService {
            outcome = "successful";
            recorder = successRecorder;
            reportArgs = "true %i";
          };

          "backup-failed@" = mkOutcomeService {
            outcome = "failed";
            recorder = failureRecorder;
            reportArgs = "false %i 'backup job %i failed on ${config.networking.hostName}'";
          };
        };

      timers = lib.mapAttrs' (
        name: job:
        lib.nameValuePair "backup-${name}" {
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnCalendar = job.at;
            Persistent = true;
            AccuracySec = "1m";
            RandomizedDelaySec = "2m";
          };
        }
      ) cfg.jobs;
    };

    assertions = [
      {
        assertion = !(hasDuplicateTimeSlot cfg.jobs);
        message = "homelab.backup.jobs on ${config.networking.hostName} share a slot";
      }
    ]
    ++ lib.concatLists (lib.mapAttrsToList databaseAssertions cfg.jobs)
    ++ lib.concatLists (lib.mapAttrsToList treeAssertions cfg.jobs);
  };
}
