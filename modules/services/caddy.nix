{ config, ... }:
{
  services.caddy = {
    enable = true;
    openFirewall = true;
    virtualHosts."localhost".extraConfig = ''
      respond "OK"
      tls internal
    '';
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "060f4ce11d3b1417b63b052e2237079adfb6f50b39e0d22e0d18e5337e7f3821@guster.xyz";

    certs."guster.xyz" = {
      group = config.services.caddy.group;

      domain = "guster.xyz";
      extraDomainNames = [ "*.guster.xyz" ];
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      dnsPropagationCheck = true;
      environmentFile = config.sops.templates."acme.env".path;
    };
  };

  sops = {
    secrets = {
      "acme/cloudflareToken" = { };
    };

    templates."acme.env".content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder."acme/cloudflareToken"}
    '';
  };
}
