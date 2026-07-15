{ lib, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/omada.nix
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "mongodb-ce";

  networking = {
    hostName = "omada";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.10.2"; prefixLength = 27; }
    ];
    defaultGateway = { address = "10.0.10.1"; interface = "eth0"; };
    nameservers = [ "10.0.10.1" ];
  };

  system.stateVersion = "26.05";
}
