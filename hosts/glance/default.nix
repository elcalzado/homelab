{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/glance.nix
  ];

  networking.hostName = "glance";

  system.stateVersion = "26.05";
}
