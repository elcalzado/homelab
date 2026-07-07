# Declarative disk layout (disko) for VM / bare-metal hosts: GPT with an EFI
# system partition and a btrfs root (subvolumes for /, /nix, /home).
# Device defaults to /dev/sda (Proxmox virtio-scsi, most SATA/SCSI); a bare-metal
# host on a different disk overrides `disko.devices.disk.main.device` in its host file.
{ inputs, lib, ... }:
{
  imports = [ inputs.disko.nixosModules.disko ];

  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "/rootfs" = { mountpoint = "/";     mountOptions = [ "compress=zstd" "noatime" ]; };
              "/nix"    = { mountpoint = "/nix";  mountOptions = [ "compress=zstd" "noatime" ]; };
              "/home"   = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
            };
          };
        };
      };
    };
  };
}
