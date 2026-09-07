{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) isx86_64;
  serialPort = if isx86_64 then "ttyS0" else "ttyAMA0";
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

    kernelParams = [
      "console=${serialPort},115200"
      "console=tty0"
    ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault isx86_64;
    cpu.amd.updateMicrocode = lib.mkDefault isx86_64;
  };

  # Additional serial login console
  systemd.services."serial-getty@${serialPort}".enable = true;

  services.qemuGuest.enable = true;

  disko.devices.disk.main.device = "/dev/sda";
}
