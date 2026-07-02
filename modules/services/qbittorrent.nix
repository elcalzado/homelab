{ config, pkgs, lib, ... }:

let
  # --- Tunables ---

  # LAN
  lanInterface = "eth0";           # usePredictableInterfaceNames=false
  lanNet       = "10.0.30.0/26";
  lanGateway   = "10.0.30.1";
  mgmtNet      = "10.0.100.0/28"; 

  # WireGuard tunnel
  wgAddress = "10.2.0.2/32";
  wgDns     = "10.2.0.1";

  # VPN peer/endpoint
  vpnPublicKey    = "D7+AG9clQ1F/6uaY8apeoKDOKAD7p6tf65dFIVLGsHg=";
  vpnEndpointIp   = "149.102.224.162";
  vpnEndpointPort = 51820;

  # Storage / qBittorrent
  saveDir  = "/mnt/quarantine";
  tempDir  = "/mnt/quarantine/temp";
  webuiPort = 8080;

  qbtUser  = "qbtuser";
  qbtUid = 3002;
  profileDir = "/var/lib/qbittorrent";
  configFile = "${profileDir}/qBittorrent/config/qBittorrent.conf";
  scanLog  = "/var/log/qbittorrent/clamav_scan.log";

  # ClamAV post-download scanner
  clamavScan = pkgs.writeShellApplication {
    name = "clamav_scan";
    runtimeInputs = [ pkgs.clamav pkgs.coreutils ];
    text = ''
      SCAN_LOG=${lib.escapeShellArg scanLog}
      ${builtins.readFile ../../scripts/qbittorrent/clamav_scan.sh}
    '';
  };

  # VPN NAT-PMP port forwarding
  portForward = pkgs.writeShellApplication {
    name = "vpn-portforward";
    runtimeInputs = [ pkgs.libnatpmp pkgs.curl pkgs.gnused pkgs.coreutils ];
    text = ''
      GATEWAY=${lib.escapeShellArg wgDns}
      WEBUI_PORT=${toString webuiPort}
      ${builtins.readFile ../../scripts/qbittorrent/vpn-portforward.sh}
    '';
  };

  # Seed qBittorrent.conf ONCE (copy-if-missing). serverConfig is left empty so
  # the module does not overwrite this file on every restart, which lets runtime
  # WebUI edits (crucially the admin password) persist. The WebUI password is
  # therefore NOT stored in the repo: on first start qBittorrent prints a
  # temporary password to its journal; set a permanent one via the WebUI.
  seedConfig = pkgs.writeText "qBittorrent.conf" ''
    [AutoRun]
    enabled=true
    program=${clamavScan}/bin/clamav_scan "%F"

    [BitTorrent]
    Session\DefaultSavePath=${saveDir}
    Session\TempPath=${tempDir}
    Session\TempPathEnabled=true

    [LegalNotice]
    Accepted=true

    [Preferences]
    General\Locale=en
    WebUI\Username=guster
    WebUI\LocalHostAuth=false
  '';
in
{
  # --- qBittorrent ---
  services.qbittorrent = {
    enable = true;
    user = qbtUser;
    group = qbtUser;
    inherit profileDir webuiPort;
    openFirewall = false;
    # Left empty on purpose
    serverConfig = { };
  };

  users.users.${qbtUser} = {
    isSystemUser = true;
    uid = qbtUid;
    group = qbtUser;
  };
  users.groups.${qbtUser} = { };

  # Dedicated log dir + one-time config seed
  systemd.tmpfiles.rules = [
    "d /var/log/qbittorrent 0755 ${qbtUser} ${qbtUser} -"
    "d ${profileDir}/qBittorrent/config 0755 ${qbtUser} ${qbtUser} -"
    "C ${configFile} 0600 ${qbtUser} ${qbtUser} - ${seedConfig}"
  ];

  # Don't start writing torrents into an empty mountpoint
  systemd.services.qbittorrent = {
    unitConfig.RequiresMountsFor = [ saveDir ];
    after = [ "wg-quick-wg0.service" ];
  };

  # --- WireGuard ---
  networking.wg-quick.interfaces.wg0 = {
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

  # --- VPN port forwarding (NAT-PMP) ---
  systemd.services.vpn-portforward = {
    description = "VPN NAT-PMP port forwarding for qBittorrent";
    after = [ "wg-quick-wg0.service" "qbittorrent.service" ];
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

  # --- Kill-switch (nftables) —--
  networking.firewall.enable = false;
  networking.nftables = {
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

  # --- Split-DNS (dnsmasq) —--
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;      # point the system resolver at 127.0.0.1
    settings = {
      no-resolv = true;
      bind-interfaces = true;
      listen-address = "127.0.0.1";
      server = [
        "/home.arpa/${lanGateway}"   # LAN names -> LAN resolver
        wgDns                        # everything else -> VPN DNS
      ];
    };
  };

  # --- ClamAV ---
  services.clamav.updater.enable = true;

  environment.systemPackages = [ clamavScan pkgs.wireguard-tools pkgs.libnatpmp ];
}
