{ lib, ... }:
{
  # --- Bootloader ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # IMPORTANT: a *default* Proxmox VM uses legacy BIOS (SeaBIOS), NOT UEFI.
  # For a BIOS machine, comment out the two lines above and use GRUB instead:
  #   boot.loader.grub.enable = true;
  #   boot.loader.grub.device = "/dev/sda";   # the disk, adjust as needed

  # Pull an address by default; override per-host for a static IP.
  networking.useDHCP = lib.mkDefault true;

  # Keep for any QEMU/KVM VM; remove on true baremetal.
  services.qemuGuest.enable = true;
}
