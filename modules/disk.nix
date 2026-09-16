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
        "/home" = {
          mountpoint = "/home";
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

  resolveDisks =
    { userDisks, defaultDevice }:
    if userDisks != { } then userDisks else { default = defaultDevice; };

  resolvePartitions =
    { userPartitions, defaultPartitions }:
    if userPartitions != { } then userPartitions else defaultPartitions;

  hasPartitionRole = role: partitions: partitions ? ${role};

  stripHomeSubvolume =
    rootContent:
    rootContent
    // {
      subvolumes = lib.removeAttrs (rootContent.subvolumes or { }) [ "/home" ];
    };

  resolveRoleContent =
    { roleContent, partitions }:
    if hasPartitionRole "home" partitions then
      roleContent // { root = stripHomeSubvolume roleContent.root; }
    else
      roleContent;

  partitionsAssignedToDisk =
    diskName: partitions: lib.filterAttrs (_: partition: partition.disk == diskName) partitions;

  wholeDiskAsDataPartition = {
    data = {
      size = "100%";
    };
  };

  partitionsForDisk =
    diskName: partitions:
    let
      assigned = partitionsAssignedToDisk diskName partitions;
    in
    if assigned == { } then wholeDiskAsDataPartition else assigned;

  partitionTypeCode = role: if role == "boot" then "EF00" else null;

  mkPartitionSpec =
    roleContent: role: partitionCfg:
    let
      content = roleContent.${role} or { };
      type = partitionTypeCode role;
    in
    {
      inherit (partitionCfg) size;
    }
    // lib.optionalAttrs (type != null) { inherit type; }
    // lib.optionalAttrs (content != { }) { inherit content; };

  mkDiskEntry = roleContent: partitions: diskName: device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = lib.mapAttrs (mkPartitionSpec roleContent) (partitionsForDisk diskName partitions);
    };
  };

  definesNamedDisksWithoutPartitions =
    disks: partitions: disks != { } && partitions == { } && !(disks ? "default");
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
          !(definesNamedDisksWithoutPartitions (targetConfig.diskLayout.disks or { }) (
            targetConfig.diskLayout.partitions or { }
          ));
        message = "When defining diskLayout.disks without a 'default' disk, you must also define diskLayout.partitions.";
      }
    ];

    disko.devices.disk =
      let
        effectiveDisks = resolveDisks {
          userDisks = targetConfig.diskLayout.disks or { };
          defaultDevice = config.homelab.disk.defaultDevice;
        };

        effectivePartitions = resolvePartitions {
          userPartitions = targetConfig.diskLayout.partitions or { };
          inherit defaultPartitions;
        };

        effectiveRoleContent = resolveRoleContent {
          roleContent = config.homelab.disk.roleContent;
          partitions = effectivePartitions;
        };
      in
      lib.mapAttrs (mkDiskEntry effectiveRoleContent effectivePartitions) effectiveDisks;
  };
}
