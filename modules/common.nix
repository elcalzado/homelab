{ config, lib, pkgs, inputs, ... }:

let
  gusterUid = 1000;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./backup.nix
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "guster" "deploy" ];
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      UseDns = true;
    };
  };

  security.sudo = {
    wheelNeedsPassword = true;

    extraRules = [
      {
        users = [ "deploy" ];
        commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
      }
    ];
  };

  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.secrets."guster/passwordHash".neededForUsers = true;

  users = {
    mutableUsers = false;

    groups = {
      guster.gid = gusterUid;
      deploy = { };
    };

    users = {
      guster = {
        isNormalUser = true;
        uid = gusterUid;
        group = "guster";
        extraGroups = [ "wheel" ];
        hashedPasswordFile = config.sops.secrets."guster/passwordHash".path;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICrOEgaElLZiqDSSQy/NkyhIqfSnMGlRz/iHR6SXvL5Y" # tap-man
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGypMPZRySmPafnRuN1v48iNwXag/vMJdgkRQnKL5+5K" # magichead
        ];
      };

      root.hashedPassword = "!";

      deploy = {
        isNormalUser = true;
        group = "deploy";
        openssh.authorizedKeys.keys = [
          ''from="runner.home.arpa",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqCbLUC2OL40NzX9gHg6J7vSC6B+6GFLUXYJcElfcpo deploy@runner''
        ];
      };
    };
  };

  # No DHCP by default.
  networking.useDHCP = lib.mkDefault false;

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [ git vim rsync ];
}
