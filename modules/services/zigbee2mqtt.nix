{ config, ... }:
let
  serialPort = "/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_00D9B686-if00-port0";
  mqttPort = 1883;
  inherit (config.services.zigbee2mqtt) dataDir;
in
{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = mqttPort;
        settings.allow_anonymous = false;
        users = {
          zigbee2mqtt = {
            passwordFile = config.sops.secrets."mosquitto/zigbee2mqttPassword".path;
            acl = [
              "readwrite zigbee2mqtt/#"
              "readwrite homeassistant/#"
            ];
          };
          home-assistant = {
            passwordFile = config.sops.secrets."mosquitto/homeAssistantPassword".path;
            acl = [ "readwrite #" ];
          };
        };
      }
    ];
  };

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant.enabled = true;
      permit_join = false;
      serial = {
        port = serialPort;
        adapter = "ember";
      };
      mqtt = {
        server = "mqtt://localhost:${toString mqttPort}";
        base_topic = "zigbee2mqtt";
        user = "zigbee2mqtt";
        password = "!secret mqtt_password";
      };
      advanced = {
        network_key = "!secret network_key";
        pan_id = 55065;
        ext_pan_id = [
          62
          212
          184
          190
          125
          245
          165
          170
        ];
        channel = 20;
        log_output = [ "console" ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ mqttPort ];

  systemd.services.zigbee2mqtt = {
    after = [ "mosquitto.service" ];
    wants = [ "mosquitto.service" ];
  };

  sops.secrets = {
    "mosquitto/zigbee2mqttPassword" = { };
    "mosquitto/homeAssistantPassword" = { };
    "zigbee2mqtt/networkKey" = { };
  };

  sops.templates."zigbee2mqtt-secret.yaml" = {
    content = ''
      mqtt_password: ${config.sops.placeholder."mosquitto/zigbee2mqttPassword"}
      network_key: ${config.sops.placeholder."zigbee2mqtt/networkKey"}
    '';
    owner = "zigbee2mqtt";
    group = "zigbee2mqtt";
    path = "${dataDir}/secret.yaml";
  };

  homelab.backup.jobs.zigbee2mqtt = {
    at = "00:10";
    trees = [ dataDir ];
    excludes = [ "secret.yaml" ];
  };
}
