{ lib, ... }:
{
  boot = {
    # --- Bootloader ---
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # IMPORTANT: a *default* Proxmox VM uses legacy BIOS (SeaBIOS), NOT UEFI.
    # For a BIOS machine, comment out the two lines above and use GRUB instead:
    #   boot.loader.grub.enable = true;
    #   boot.loader.grub.device = "/dev/sda";   # the disk, adjust as needed

    # Keep normal VGA/noVNC as the primary console
    kernelParams = [
      "console=ttyS0,115200"
      "console=tty0"
    ];

    # Covers Proxmox virtio VMs and common baremetal (AHCI/NVMe/USB).
    initrd.availableKernelModules = [
      "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "virtio_blk" "sd_mod" "sr_mod" "nvme" "usbhid"
    ];
  };

  # Add an additional serial login console
  systemd.services."serial-getty@ttyS0".enable = true;

  # Keep for any QEMU/KVM VM; harmless (inactive) on true baremetal.
  services.qemuGuest.enable = true;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault true;
    cpu.amd.updateMicrocode = lib.mkDefault true;
  };
}
