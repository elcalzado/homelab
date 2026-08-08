{ config, pkgs, lib, ... }:

let
  lanInterface = "eth0";
  lanNet       = "10.0.30.0/26";
  lanGateway   = "10.0.30.1";
  mgmtNet      = "10.0.100.0/28";

  wgAddress = "10.2.0.2/32";
  wgDns     = "10.2.0.1";

  vpnPublicKey    = "D7+AG9clQ1F/6uaY8apeoKDOKAD7p6tf65dFIVLGsHg=";
  vpnEndpointIp   = "149.102.224.162";
  vpnEndpointPort = 51820;

  mountDir = "/mnt/entertainment";
  saveDir  = "${mountDir}/torrents";
  tempDir  = "${saveDir}/temp";
  webuiPort = 8080;

  profileDir = "/var/lib/qbittorrent";
  configDir  = "${profileDir}/qBittorrent/config";
  resumeDir  = "${profileDir}/qBittorrent/data/BT_backup";
  configFile = "${configDir}/qBittorrent.conf";
  scanLog  = "/var/log/qbittorrent/clamav_scan.log";
  clamavDb = "/var/lib/clamav";

  clamavScan = pkgs.writeShellApplication {
    name = "clamav_scan";
    runtimeInputs = [ pkgs.clamav pkgs.coreutils ];
    text = ''
      SCAN_LOG=${lib.escapeShellArg scanLog}
      CLAMAV_DB=${lib.escapeShellArg clamavDb}
      ${builtins.readFile ../../scripts/qbittorrent/clamav_scan.sh}
    '';
  };

  portForward = pkgs.writeShellApplication {
    name = "vpn-portforward";
    runtimeInputs = [ pkgs.libnatpmp pkgs.curl pkgs.gnused pkgs.coreutils ];
    text = ''
      GATEWAY=${lib.escapeShellArg wgDns}
      WEBUI_PORT=${toString webuiPort}
      ${builtins.readFile ../../scripts/qbittorrent/vpn-portforward.sh}
    '';
  };

  # Declarative qBittorrent.conf, rendered from configs/qbittorrent/qBittorrent.conf
  # with @TOKENS@ substituted.
  qbtConfBody = builtins.replaceStrings
    [ "@CLAMAV_SCAN@" "@SAVE_DIR@" "@TEMP_DIR@" ]
    [ (lib.getExe clamavScan) saveDir tempDir ]
    (builtins.readFile ../../configs/qbittorrent/qBittorrent.conf);
  # Guarantee a trailing newline so the WebUI password hash has its own line
  qbtConfBase = pkgs.writeText "qBittorrent.conf"
    (qbtConfBody + lib.optionalString (!lib.hasSuffix "\n" qbtConfBody) "\n");
in
{
  services = {
    qbittorrent = {
      enable = true;
      group = "entertainment";
      inherit profileDir webuiPort;
      openFirewall = false;
      # Left empty on purpose
      serverConfig = { };
    };

    dnsmasq = {
      enable = true;
      resolveLocalQueries = true;      # point the system resolver at 127.0.0.1
      settings = {
        no-resolv = true;
        bind-interfaces = true;
        listen-address = "127.0.0.1";
        server = [
          "/home.arpa/${lanGateway}"
          wgDns
        ];
      };
    };

    clamav.updater.enable = true;
  };

  sops.secrets = {
    "wireguard/privateKey" = { };
    "webui/passwordHash" = {
      owner = config.services.qbittorrent.user;
      restartUnits = [ "qbittorrent.service" ];
    };
    "webui/apiKey" = {
      owner = config.services.qbittorrent.user;
      restartUnits = [ "qbittorrent.service" ];
    };
  };

  homelab.backup.jobs.qbittorrent = {
    at = "02:50";
    trees = [ resumeDir configDir ];
    excludes = [ "qBittorrent.conf" "lockfile" ];
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/log/qbittorrent 0755 ${config.services.qbittorrent.user} ${config.services.qbittorrent.group} -"
      "d ${profileDir}/qBittorrent/config 0755 ${config.services.qbittorrent.user} ${config.services.qbittorrent.group} -"
    ];

    services.qbittorrent = {
      serviceConfig.UMask = "0002";
      unitConfig.RequiresMountsFor = [ mountDir ];
      after = [ "wg-quick-wg0.service" ];
      # Rewrite the config authoritatively on every start, then append the WebUI
      # password hash and API key from the sops secrets.
      restartTriggers = [ qbtConfBase ];
      preStart = ''
        ${pkgs.coreutils}/bin/install -m600 ${qbtConfBase} ${configFile}
        printf 'WebUI\\Password_PBKDF2=%s\n' "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."webui/passwordHash".path})" >> ${configFile}
        printf 'WebUI\\APIKey=%s\n' "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."webui/apiKey".path})" >> ${configFile}
      '';
    };

    services.vpn-portforward = {
      description = "VPN NAT-PMP port forwarding for qBittorrent";
      after = [ "wg-quick-wg0.service" "qbittorrent.service" ];
      partOf = [ "qbittorrent.service" ];
      wants = [ "wg-quick-wg0.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = lib.getExe portForward;
        Restart = "always";
        RestartSec = 10;
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };

  networking = {
    wg-quick.interfaces.wg0 = {
      address = [ wgAddress ];
      privateKeyFile = config.sops.secrets."wireguard/privateKey".path;
      # DNS deliberately unset here: split-DNS is handled declaratively by dnsmasq
      postUp = [
        "${pkgs.iproute2}/bin/ip route replace ${mgmtNet} via ${lanGateway} dev ${lanInterface}"
      ];
      preDown = [
        "${pkgs.iproute2}/bin/ip route del ${mgmtNet}"
      ];
      peers = [{
        publicKey = vpnPublicKey;
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "${vpnEndpointIp}:${toString vpnEndpointPort}";
        persistentKeepalive = 25;
      }];
    };

    firewall.enable = false;
    nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority filter; policy drop;

            iif "lo" accept
            ct state established,related accept

            # WireGuard handshake with the VPN endpoint
            ip saddr ${vpnEndpointIp} udp sport ${toString vpnEndpointPort} accept

            # All traffic over the tunnel
            iifname "wg0" accept

            # LAN + management segments (SSH, WebUI, NFS to the NAS, DNS to gateway)
            ip saddr ${lanNet} accept
            ip saddr ${mgmtNet} accept
          }

          chain forward {
            type filter hook forward priority filter; policy drop;
          }

          chain output {
            type filter hook output priority filter; policy drop;

            oif "lo" accept
            ct state established,related accept

            ip daddr ${vpnEndpointIp} udp dport ${toString vpnEndpointPort} accept
            oifname "wg0" accept
            ip daddr ${lanNet} accept
            ip daddr ${mgmtNet} accept
          }
        }
      '';
    };
  };

  environment.systemPackages = [ clamavScan pkgs.wireguard-tools pkgs.libnatpmp ];
}
