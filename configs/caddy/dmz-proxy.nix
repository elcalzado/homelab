let
  certloc = "/var/lib/acme";
  domain = "guster.xyz";
in
{
  services.caddy = {
    virtualHosts = {
      "dmz.guster.xyz".extraConfig = ''
        respond "OK"

        tls ${certloc}/${domain}/cert.pem ${certloc}/${domain}/key.pem {
          protocols tls1.3
        }
      '';
    };
  };
}
