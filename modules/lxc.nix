{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  nix.settings.sandbox = false;

  proxmoxLXC = {
    manageNetwork = false;
    privileged = false;
  };

  services.fstrim.enable = false;
}
