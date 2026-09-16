{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) isx86_64;
in
{
  imports = [
    ./disk.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "sd_mod"
      "sr_mod"
      "nvme"
      "usbhid"
    ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault isx86_64;
    cpu.amd.updateMicrocode = lib.mkDefault isx86_64;
  };

  # No disk definitions by default. Each pc host defines real drives in meta.nix.
  homelab.disk.enable = true;
}
