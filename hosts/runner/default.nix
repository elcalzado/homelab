_:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/runner.nix
  ];

  homelab.runner = {
    url = "https://github.com/elcalzado/homelab";
    builder = {
      host = "builder.home.arpa";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjsSWzDvE1vcEiPo3lJSGhTTNiajKOiwrpQS3uE5f9J";
    };
  };

  networking = {
    hostName = "runner";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.12"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  sops.defaultSopsFile = ../../secrets/runner.yaml;

  system.stateVersion = "26.05";
}
