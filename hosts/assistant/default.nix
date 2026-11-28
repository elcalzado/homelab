{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/zwave-js.nix
    ../../modules/services/zigbee2mqtt.nix
  ];

  networking = {
    hostName = "assistant";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "10.0.30.2";
        prefixLength = 26;
      }
    ];
    defaultGateway = {
      address = "10.0.30.1";
      interface = "eth0";
    };
    nameservers = [ "10.0.30.1" ];
  };

  sops.defaultSopsFile = ../../secrets/assistant.yaml;

  system.stateVersion = "26.05";
}
