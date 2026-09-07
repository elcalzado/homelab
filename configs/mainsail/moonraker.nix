{
  services.moonraker.settings = {
    file_manager.enable_object_processing = true;

    authorization = {
      trusted_clients = [
        "192.168.0.0/16"
        "10.0.0.0/8"
        "127.0.0.0/8"
        "169.254.0.0/16"
        "172.16.0.0/12"
        "FC00::/7"
        "FE80::/10"
        "::1/128"
      ];
      cors_domains = [
        "*.lan"
        "*.local"
        "*://localhost"
        "*://localhost:*"
        "https://mainsail.guster.xyz"
      ];
    };

    octoprint_compat = { };
    history = { };
  };
}
