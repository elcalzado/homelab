{
  services.caddy = {
    virtualHosts = {
      "example.org".extraConfig = ''
        respond "Goodbye world..."
        tls internal
      '';
    };
  };
}
