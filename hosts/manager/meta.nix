{
  targets = {
    arm64-rpi = {
      channel = "stable";
      board = "rpi-5";
      useDisko = true;
      diskLayout = {
        disks.nvme = "/dev/nvme0n1";
        partitions.root = {
          disk = "nvme";
          size = "100%";
        };
      };
    };
  };
}
