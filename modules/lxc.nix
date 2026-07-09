{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  nix.settings.sandbox = false;

  proxmoxLXC = {
    manageNetwork = true;
    privileged = false;
  };

  networking.useHostResolvConf = false;

  services.fstrim.enable = false;
}
