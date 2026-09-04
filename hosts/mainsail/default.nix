{ config, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/mainsail.nix
  ];

  networking = {
    hostName = "mainsail";
    usePredictableInterfaceNames = false;
    interfaces.wlan0.ipv4.addresses = [
      { address = "10.0.30.4"; prefixLength = 26; }
    ];
    defaultGateway = { address = "10.0.30.1"; interface = "wlan0"; };
    nameservers = [ "10.0.30.1" ];

    wireless = {
      enable = true;
      secretsFile = config.sops.templates."wireless.conf".path;
    };
  };

  sops = {
    defaultSopsFile = ../../secrets/mainsail.yaml;

    secrets."wireless/ssid" = { };
    secrets."wireless/psk" = { };

    templates."wireless.conf".content = ''
        network={
        ssid="${config.sops.placeholder."wireless/ssid"}"
        psk="${config.sops.placeholder."wireless/psk"}"
        }
    '';
  };

  system.stateVersion = "26.05";
}
