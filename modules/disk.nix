{
  config,
  lib,
  targetConfig,
  inputs,
  ...
}:
let
  defaultRoleContent = {
    boot = {
      type = "filesystem";
      format = "vfat";
      mountpoint = "/boot";
      mountOptions = [ "umask=0077" ];
    };
    root = {
      type = "btrfs";
      extraArgs = [ "-f" ];
      subvolumes = {
        "/rootfs" = {
          mountpoint = "/";
          mountOptions = [
            "compress=zstd"
            "noatime"
          ];
        };
        "/nix" = {
          mountpoint = "/nix";
          mountOptions = [
            "compress=zstd"
            "noatime"
          ];
        };
      };
    };
    home = {
      type = "btrfs";
      extraArgs = [ "-f" ];
      mountpoint = "/home";
      mountOptions = [
        "compress=zstd"
        "noatime"
      ];
    };
    swap = {
      type = "swap";
    };
    data = { };
  };

  defaultPartitions = {
    boot = {
      disk = "default";
      size = "512M";
    };
    root = {
      disk = "default";
      size = "100%";
    };
  };
in
{
  imports = [ inputs.disko.nixosModules.disko ];

  options.homelab.disk = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable disko-managed disks.";
    };

    defaultDevice = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Default disk, set by platform module.";
    };

    roleContent = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = defaultRoleContent;
      description = "Disko content configuration for each partition role.";
    };
  };

  config = lib.mkIf config.homelab.disk.enable {
    assertions = [
      {
        assertion =
          !(
            targetConfig.diskLayout.disks or { } != { }
            && targetConfig.diskLayout.partitions or { } == { }
            && !((targetConfig.diskLayout.disks or { }) ? "default")
          );
        message = "When defining diskLayout.disks without a 'default' disk, you must also define diskLayout.partitions.";
      }
    ];

    disko.devices.disk =
      let
        defaultDevice = config.homelab.disk.defaultDevice;

        userDisks = targetConfig.diskLayout.disks or { };
        userPartitions = targetConfig.diskLayout.partitions or { };

        effectiveDisks = if userDisks != { } then userDisks else { default = defaultDevice; };
        effectivePartitions = if userPartitions != { } then userPartitions else defaultPartitions;

        diskEntry =
          diskName: device:
          let
            assignedPartitions = lib.filterAttrs (_: p: p.disk == diskName) effectivePartitions;

            finalPartitions =
              if assignedPartitions == { } then
                {
                  data = {
                    size = "100%";
                  };
                }
              else
                assignedPartitions;
          in
          {
            type = "disk";
            inherit device;
            content = {
              type = "gpt";
              partitions = lib.mapAttrs (
                roleName: roleCfg:
                let
                  content = config.homelab.disk.roleContent.${roleName} or { };
                  type = if roleName == "boot" then "EF00" else null;
                in
                {
                  inherit (roleCfg) size;
                }
                // lib.optionalAttrs (type != null) { inherit type; }
                // lib.optionalAttrs (content != { }) { inherit content; }
              ) finalPartitions;
            };
          };
      in
      lib.mapAttrs diskEntry effectiveDisks;
  };
}
