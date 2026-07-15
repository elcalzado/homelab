{ pkgs, lib, ... }:

let
  version = "6.2.10.17";

  omadaUser = "omada";
  omadaUid  = 2000;

  omadaHome = "/opt/tplink/EAPController";
  stateDir  = "/var/lib/omada";

  httpPort    = 8088;
  httpsPort   = 8043;
  portalHttps = 8843;

  maxHeap = "2048m";

  jre       = pkgs.openjdk21_headless;
  jsvc      = pkgs.jsvc.override { jre = jre; jdk = pkgs.openjdk21; };
  jsvcBin   = lib.getExe jsvc;
  mongodBin = lib.getExe' pkgs.mongodb-ce "mongod";

  classpath = "${pkgs.commons-daemon}/share/java/*:${omadaHome}/lib/*:${omadaHome}/properties";

  javaOpts = [
    "-server"
    "-Xmx${maxHeap}"
    "-XX:MaxHeapFreeRatio=60"
    "-XX:MinHeapFreeRatio=30"
    "-XX:+HeapDumpOnOutOfMemoryError"
    "-XX:HeapDumpPath=${stateDir}/logs/java_heapdump.hprof"
    "-Djava.awt.headless=true"
    "-Djdk.lang.Process.launchMechanism=vfork"
  ];

  mainClass = "com.tplink.smb.omada.starter.OmadaLinuxMain";

  omada-controller = pkgs.stdenv.mkDerivation {
    pname = "omada-controller";
    inherit version;

    # The download URL is not derivable from the version. On a bump, copy the new link from
    # TP-Link's download page and refresh the hash: nix store prefetch-file <url>
    src = pkgs.fetchurl {
      url  = "https://static.tp-link.com/upload/software/2026/202604/20260429/Omada_Network_Application_v${version}_linux_x64_20260428102037.tar.gz";
      hash = "sha256-1euU8jW2747kLQUhSY6Eopne1E+OZ65vu3TFK9SCJCU=";
    };

    dontConfigure = true;
    dontBuild     = true;
    dontPatchELF  = true;
    dontStrip     = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r lib properties data "$out/"
      runHook postInstall
    '';
  };

  dataDirs = [ "db" "keystore" "autobackup" "pdf" "cluster" "device-firmware" "chromium" "check-mongo" ];
in
{
  users.groups.${omadaUser}.gid = omadaUid;
  users.users.${omadaUser} = {
    isSystemUser = true;
    uid   = omadaUid;
    group = omadaUser;
    home  = stateDir;
  };

  systemd.tmpfiles.rules = [
    "d  /opt/tplink                              0755 root         root         -"
    "d  ${omadaHome}                             0755 ${omadaUser} ${omadaUser} -"
    "d  ${omadaHome}/bin                         0755 ${omadaUser} ${omadaUser} -"
    "d  ${omadaHome}/lib                         0755 ${omadaUser} ${omadaUser} -"
    "d  ${omadaHome}/properties                  0750 ${omadaUser} ${omadaUser} -"
    "L+ ${omadaHome}/bin/mongod                  - - - - ${mongodBin}"
    "L+ ${omadaHome}/data                        - - - - ${stateDir}/data"
    "L+ ${omadaHome}/logs                        - - - - ${stateDir}/logs"
    "L+ ${omadaHome}/work                        - - - - ${stateDir}/work"
    "d  ${stateDir}                              0750 ${omadaUser} ${omadaUser} -"
    "d  ${stateDir}/data                         0750 ${omadaUser} ${omadaUser} -"
    "d  ${stateDir}/logs                         0750 ${omadaUser} ${omadaUser} -"
    "d  ${stateDir}/work                         0750 ${omadaUser} ${omadaUser} -"
    "L+ ${stateDir}/data/html                    - - - - ${omada-controller}/data/html"
    "L+ ${stateDir}/data/static                  - - - - ${omada-controller}/data/static"
    # log4j2 tracks the store read-only; omada.properties is a writable copy the controller rewrites
    "C  ${omadaHome}/properties/omada.properties  0640 ${omadaUser} ${omadaUser} - ${omada-controller}/properties/omada.properties"
    "L+ ${omadaHome}/properties/log4j2.properties - - - - ${omada-controller}/properties/log4j2.properties"
  ] ++ map (d: "d ${stateDir}/data/${d} 0750 ${omadaUser} ${omadaUser} -") dataDirs;

  systemd.services.omada = {
    description = "TP-Link Omada SDN Controller";
    wantedBy = [ "multi-user.target" ];
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];

    restartTriggers = [ omada-controller pkgs.commons-daemon jsvc ];

    path = [ pkgs.bash ];   # Omada execs `sh` to spawn its child mongod

    environment = {
      HOME            = stateDir;
      OMADA_HOME      = omadaHome;
      XDG_CONFIG_HOME = "${omadaHome}/data/chromium";
    };

    serviceConfig = {
      Type  = "simple";
      User  = omadaUser;
      Group = omadaUser;

      RuntimeDirectory = "omada";
      WorkingDirectory = "${omadaHome}/lib";
      ExecStart = lib.concatStringsSep " " ([
        jsvcBin "-nodetach" "-home" jre.home "-cwd" "${omadaHome}/lib"
        "-procname" "omada" "-pidfile" "/run/omada/omada.pid"
        "-outfile" "&2" "-errfile" "&2" "-cp" classpath
      ] ++ javaOpts ++ [ mainClass "start" ]);
      ExecStop = lib.concatStringsSep " " [
        jsvcBin "-stop" "-home" jre.home "-cwd" "${omadaHome}/lib"
        "-pidfile" "/run/omada/omada.pid" "-cp" classpath mainClass "stop"
      ];

      Restart         = "on-failure";
      RestartSec      = 10;
      TimeoutStartSec = 300;
      TimeoutStopSec  = 120;
      LimitNOFILE     = 65536;

      NoNewPrivileges       = true;
      PrivateTmp            = true;
      ProtectSystem         = "strict";
      ReadWritePaths        = [ omadaHome stateDir ];
      # Bind-mount (not symlink) the store jars at the /opt path, so Omada's realpath() of a
      # loaded jar stays under /opt instead of the read-only Nix store.
      BindReadOnlyPaths     = [ "${omada-controller}/lib:${omadaHome}/lib" ];
      ProtectHome           = true;
      ProtectControlGroups  = true;
      ProtectKernelTunables = true;
      RestrictSUIDSGID      = true;
      # Don't add MemoryDenyWriteExecute or SystemCallFilter: they break the JVM JIT and the mongod fork.
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ httpPort httpsPort portalHttps ];
    allowedTCPPortRanges = [ { from = 29810; to = 29817; } ];   # device adoption / management
    allowedUDPPorts = [ 27001 29810 19810 ];                    # discovery
  };
}
