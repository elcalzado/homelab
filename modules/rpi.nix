{ inputs, targetConfig, ... }:
let
  profiles = {
    rpi-zero2w = [ ];
    rpi-4 = [ inputs.nixos-hardware.nixosModules.raspberry-pi-4 ];
    rpi-5 = [ inputs.nixos-hardware.nixosModules.raspberry-pi-5 ];
  };
in
{
  imports = profiles.${targetConfig.board};

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  hardware.enableRedistributableFirmware = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
}