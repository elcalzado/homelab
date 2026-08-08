{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/gatus.nix
  ];

  networking = {
    hostName = "gatus";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.11"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  sops.defaultSopsFile = ../../secrets/gatus.yaml;

  system.stateVersion = "26.05";
}
