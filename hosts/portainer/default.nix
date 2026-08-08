{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/portainer.nix
  ];

  networking = {
    hostName = "portainer";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.10"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  sops.defaultSopsFile = ../../secrets/portainer.yaml;

  system.stateVersion = "26.05";
}
