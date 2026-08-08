_:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/builder.nix
  ];

  users.users.nixbuilder.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDvtoguMoRLIXpHSi8Nq6b8z32MUiCX/FIjZBf9Z4HcO nixbuilder@runner"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOLM3CeBJuj7a8Rf88k/iIkE5+YJrPSrm1d0fc5EnUD nixbuilder@tap-man"
  ];

  networking = {
    hostName = "builder";
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      { address = "10.0.30.13"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "eth0"; };
    nameservers = [ "10.0.30.1" ];
  };

  sops.defaultSopsFile = ../../secrets/builder.yaml;

  system.stateVersion = "26.05";
}
