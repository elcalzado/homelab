_: {
  services.caddy = {
    enable = true;
    openFirewall = true;
    virtualHosts."localhost".extraConfig = ''
      respond "Hello, world!"
      tls internal
    '';
  };
}
