{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/qbittorrent.nix
  ];

  networking = {
    hostName = "qbittorrent";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.5"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  # --- NFS share on TrueNAS ---
  fileSystems."/mnt/downloads" = {
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
