let
  certloc = "/var/lib/acme";
  domain = "guster.xyz";
in
{
  services.caddy = {
    virtualHosts = {
      "coolify.guster.xyz".extraConfig = ''
        reverse_proxy http://coolify.home.arpa:8000

        tls ${certloc}/${domain}/cert.pem ${certloc}/${domain}/key.pem {
          protocols tls1.3
        }
      '';
    };
  };
}
