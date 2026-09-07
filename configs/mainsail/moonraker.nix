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

    update_manager = {
      channel = "dev";
      refresh_interval = 168;
    };

    "update_manager mainsail" = {
      path = "/home/user/mainsail";
      repo = "mainsail-crew/mainsail";
      channel = "stable";
      type = "web";
    };

    "update_manager mainsail-config" = {
      managed_services = "klipper";
      origin = "https://github.com/mainsail-crew/mainsail-config.git";
      path = "/home/user/mainsail-config";
      primary_branch = "master";
      type = "git_repo";
    };

    "update_manager Klipper-Adaptive-Meshing-Purging" = {
      type = "git_repo";
      channel = "dev";
      path = "~/Klipper-Adaptive-Meshing-Purging";
      origin = "https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging.git";
      managed_services = "klipper";
      primary_branch = "main";
    };
  };
}
