{ config, lib, pkgs, inputs, ... }:

let
  gusterUid = 1000;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./backup.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  security.sudo.wheelNeedsPassword = true;

  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.secrets."guster/passwordHash".neededForUsers = true;

  users = {
    mutableUsers = false;

    groups.guster.gid = gusterUid;
    users.guster = {
      isNormalUser = true;
      uid = gusterUid;
      group = "guster";
      extraGroups = [ "wheel" ];
      hashedPasswordFile = config.sops.secrets."guster/passwordHash".path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICrOEgaElLZiqDSSQy/NkyhIqfSnMGlRz/iHR6SXvL5Y" # tap-man
      ];
    };

    users.root = {
      hashedPassword = "!";
    };
  };

  # No DHCP by default.
  networking.useDHCP = lib.mkDefault false;

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [ git vim rsync ];
}
