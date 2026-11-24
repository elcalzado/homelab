{ config, ... }:
let
  serialPort = "/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_00D9B686-if01-port0";
  secret = name: config.sops.placeholder."zwave-js/${name}";
in
{
  services.zwave-js = {
    enable = true;
    port = 3000;
    inherit serialPort;
    secretsConfigFile = config.sops.templates."zwave-js-secrets.json".path;
    settings.logConfig = {
      enabled = true;
      level = "info";
      forceConsole = true;
      logToFile = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ config.services.zwave-js.port ];

  sops.secrets = {
    "zwave-js/s0Legacy" = { };
    "zwave-js/s2Unauthenticated" = { };
    "zwave-js/s2Authenticated" = { };
    "zwave-js/s2AccessControl" = { };
    "zwave-js/lrS2Authenticated" = { };
    "zwave-js/lrS2AccessControl" = { };
  };

  sops.templates."zwave-js-secrets.json".content = builtins.toJSON {
    securityKeys = {
      S0_Legacy = secret "s0Legacy";
      S2_Unauthenticated = secret "s2Unauthenticated";
      S2_Authenticated = secret "s2Authenticated";
      S2_AccessControl = secret "s2AccessControl";
    };
    securityKeysLongRange = {
      S2_Authenticated = secret "lrS2Authenticated";
      S2_AccessControl = secret "lrS2AccessControl";
    };
  };
}
