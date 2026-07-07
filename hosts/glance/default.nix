{ config, lib, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/glance.nix
  ];

  networking.hostName = "glance";

  # VM/baremetal only; on LXC, Proxmox manages the network.
  networking.usePredictableInterfaceNames = lib.mkIf (!config.boot.isContainer) false;
  networking.interfaces.eth0.ipv4.addresses = lib.mkIf (!config.boot.isContainer) [
    { address = "10.0.30.6"; prefixLength = 26; }
  ];
  networking.defaultGateway = lib.mkIf (!config.boot.isContainer) {
    address = "10.0.30.1"; interface = "eth0";
  };

  system.stateVersion = "26.05";
}
