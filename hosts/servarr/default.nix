{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/prowlarr.nix
    ../../modules/services/sonarr.nix
    ../../modules/services/radarr.nix
    ../../modules/services/bazarr.nix
    ../../modules/services/recyclarr.nix
    ../../modules/services/seerr.nix
  ];

  networking = {
    hostName = "servarr";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.8"; prefixLength = 26; }
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
      "noauto"
      "x-systemd.automount"
    ];
  };

  sops.defaultSopsFile = ../../secrets/servarr.yaml;

  system.stateVersion = "26.05";
}
