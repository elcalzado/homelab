{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/immich.nix
  ];

  networking = {
    hostName = "immich";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.9"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  users.groups.photos.gid = 4000;

  fileSystems."/mnt/photos" = {
    device = "truenas.home.arpa:/mnt/blueberry/photos";
    fsType = "nfs";
    options = [
      "nfsvers=4"
      "_netdev"
      "x-systemd.mount-timeout=30"
    ];
  };

  sops.defaultSopsFile = ../../secrets/immich.yaml;

  system.stateVersion = "26.11";
}
