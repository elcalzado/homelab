{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  nix.settings.sandbox = false;

  proxmoxLXC = {
    manageNetwork = true;
    privileged = false;
  };

  services.fstrim.enable = false;
}
