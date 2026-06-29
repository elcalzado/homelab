{ pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICrOEgaElLZiqDSSQy/NkyhIqfSnMGlRz/iHR6SXvL5Y" # tap-man
  ];

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [ git vim ];
}
