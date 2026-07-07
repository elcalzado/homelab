{ config, lib, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/qbittorrent.nix
  ];

  networking.hostName = "qbittorrent";

  # VM/baremetal only; on LXC, Proxmox manages the network.
  networking.usePredictableInterfaceNames = lib.mkIf (!config.boot.isContainer) false;
  networking.interfaces.eth0.ipv4.addresses = lib.mkIf (!config.boot.isContainer) [
    { address = "10.0.30.5"; prefixLength = 26; }
  ];
  networking.defaultGateway = lib.mkIf (!config.boot.isContainer) {
    address = "10.0.30.1"; interface = "eth0";
  };

  # --- NFS share on TrueNAS ---
  fileSystems."/mnt/quarantine" = {
    device = "truenas.home.arpa:/mnt/Storage/quarantine";
    fsType = "nfs";
    options = [
      "nfsvers=4"
      "_netdev"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
    ];
  };

  # --- Secrets ---
  # sops.age.keyFile comes from common.nix; only the host-specific file differs.
  sops.defaultSopsFile = ../../secrets/qbittorrent.yaml;
  sops.secrets."wireguard/privateKey" = { };

  system.stateVersion = "26.05";
}
