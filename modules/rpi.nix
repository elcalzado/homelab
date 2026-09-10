{
  inputs,
  lib,
  targetConfig,
  ...
}:
let
  profiles = {
    rpi-zero2w = [ ];
    rpi-4 = [ inputs.nixos-hardware.nixosModules.raspberry-pi-4 ];
    rpi-5 = [ inputs.nixos-hardware.nixosModules.raspberry-pi-5 ];
  };

  inherit (targetConfig) board;
  usbMode = targetConfig.usbMode or null;
  useDisko = targetConfig.useDisko or false;
in
{
  imports = profiles.${board} ++ [ ./disk.nix ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  hardware.enableRedistributableFirmware = true;

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
  };

  fileSystems."/" = lib.mkIf (!useDisko) {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  homelab.disk = {
    enable = useDisko;
    defaultDevice = lib.mkDefault "/dev/mmcblk0";
    roleContent = {
      root = lib.mkDefault {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/";
        mountOptions = [ "noatime" ];
      };
    };
  };

  hardware.deviceTree.overlays = lib.optionals (board == "rpi-zero2w" && usbMode != null) [
    {
      name = "dwc2-mode";
      dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "raspberrypi,model-zero-2-w", "brcm,bcm2837";
        };

        &{/soc/usb@7e980000} {
          dr_mode = "${usbMode}";
        };
      '';
    }
  ];
  # Future overlays can be added here with their own conditions
  # ++ lib.optionals (board == "some" && someOtherFlag) [ ... ]

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
