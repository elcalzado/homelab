{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/caddy.nix
  ];

  networking = {
    hostName = "worker";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "10.0.50.2";
        prefixLength = 27;
      }
    ];
    defaultGateway = {
      address = "10.0.50.1";
      interface = "eth0";
    };
    nameservers = [ "10.0.50.1" ];
  };

  sops.defaultSopsFile = ../../secrets/worker.yaml;

  system.stateVersion = "26.05";
}
