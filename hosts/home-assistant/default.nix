{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/home-assistant.nix
  ];

  networking = {
    hostName = "home-assistant";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.15"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  sops.defaultSopsFile = ../../secrets/home-assistant.yaml;

  system.stateVersion = "26.05";
}
