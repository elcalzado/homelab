{ inputs, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/qbittorrent.nix
    inputs.sops-nix.nixosModules.sops
  ];

  networking.hostName = "qbittorrent";

  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.interfaces.eth0.ipv4.addresses = [
    { address = "10.0.30.5"; prefixLength = 26; }
  ];
  networking.defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };

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
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.defaultSopsFile = ../../secrets/qbittorrent.yaml;
  sops.secrets."wireguard/privateKey" = { };

  system.stateVersion = "26.05";
}
