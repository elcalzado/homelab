{ config, pkgs, inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings.PermitRootLogin = "no";
  };

  security.sudo.wheelNeedsPassword = true;

  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.secrets."guster/passwordHash" = {
    sopsFile = ../secrets/common.yaml;
    neededForUsers = true;
  };

  users.mutableUsers = false;

  users.users.guster = {
    isNormalUser = true;
    uid = 1000;
    group = "guster";
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets."guster/passwordHash".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICrOEgaElLZiqDSSQy/NkyhIqfSnMGlRz/iHR6SXvL5Y" # tap-man
    ];
  };
  users.groups.guster = { };

  users.users.root = {
    hashedPassword = "!";
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [ git vim ];
}
