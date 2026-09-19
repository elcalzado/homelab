{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/portainer-edge-agent.nix
  ];

  networking = {
    hostName = "minebox";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "10.0.50.3";
        prefixLength = 27;
      }
    ];
    defaultGateway = {
      address = "10.0.50.1";
      interface = "eth0";
    };
    nameservers = [ "10.0.50.1" ];
  };

  sops.defaultSopsFile = ../../secrets/minebox.yaml;

  system.stateVersion = "26.05";
}
