{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/jellyfin.nix
  ];

  networking = {
    hostName = "jellyfin";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.7"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  users.groups.entertainment.gid = 3000;

  fileSystems."/mnt/entertainment" = {
    device = "truenas.home.arpa:/mnt/Storage/entertainment";
    fsType = "nfs";
    options = [
      "nfsvers=4"
      "_netdev"
      "ro"
      "nofail"
    ];
  };

  system.stateVersion = "26.05";
}
