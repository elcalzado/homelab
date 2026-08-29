{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/nextcloud.nix
  ];

  networking = {
    hostName = "nextcloud";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.14"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  users.groups.documents.gid = 4010;

  fileSystems."/mnt/documents" = {
    device = "truenas.home.arpa:/mnt/blueberry/documents";
    fsType = "nfs";
    options = [
      "nfsvers=4"
      "_netdev"
      "x-systemd.mount-timeout=30"
    ];
  };

  sops.defaultSopsFile = ../../secrets/nextcloud.yaml;

  system.stateVersion = "26.05";
}
