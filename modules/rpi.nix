{
  inputs,
  lib,
  targetConfig,
  isInstaller,
  ...
}:
let
  inherit (targetConfig) board;
  usbMode = targetConfig.usbMode or null;
  useDisko = targetConfig.useDisko or false;

  boardModule =
    {
      rpi-zero2w = inputs.nixos-raspberrypi.nixosModules.raspberry-pi-02.base;
      rpi-4 = inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base;
      rpi-5 = inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base;
    }
    .${board};

  bootloader =
    {
      rpi-zero2w = "uboot";
      rpi-4 = "uboot";
      rpi-5 = "kernel";
    }
    .${board};
in
{
  imports = [
    boardModule
    ./disk.nix
  ]
  ++ lib.optionals (!isInstaller) [
    inputs.nixos-raspberrypi.lib.inject-overlays
  ];

  boot = {
    loader.raspberry-pi = {
      inherit bootloader;
      firmwarePath = "/boot/firmware";
    };
    zfs.forceImportRoot = false;
  };

  hardware.raspberry-pi.config.all = {
    dt-overlays = {
      # Workaround to get Zero 2W to boot; unsure what the cause is though
      vc4-kms-v3d = lib.mkIf (board == "rpi-zero2w") {
        enable = false;
      };
      # To enable UART serial console; rpi-4 may need the same option
      miniuart-bt = lib.mkIf (board == "rpi-zero2w") {
        enable = true;
      };
      dwc2 = lib.mkIf (board == "rpi-zero2w" && usbMode != null) {
        enable = true;
        params.dr_mode = {
          enable = true;
          value = usbMode;
        };
      };
    };
  };

  # UART console for rpi-zero2w
  boot.kernelParams = lib.mkIf (board == "rpi-zero2w") [ "console=ttyAMA0,115200n8" ];

  fileSystems."/" = lib.mkIf (!useDisko) {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  homelab.disk = {
    enable = useDisko;
    defaultDevice = lib.mkDefault "/dev/mmcblk0";
    roleContent.root = lib.mkDefault {
      type = "filesystem";
      format = "ext4";
      mountpoint = "/";
      mountOptions = [ "noatime" ];
    };
  };

  # nvmd/nixos-raspberrypi sets this to true and uses iwd
  networking.networkmanager.enable = lib.mkForce false;

  assertions = [
    {
      assertion =
        usbMode == null
        || builtins.elem usbMode [
          "host"
          "otg"
          "peripheral"
        ];
      message = "usbMode must be one of \"host\", \"otg\", or \"peripheral\" (got: ${toString usbMode})";
    }
  ];
}
