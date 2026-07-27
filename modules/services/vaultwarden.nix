{ config, pkgs, ... }:

let
  domain = "vaultwarden.guster.xyz";
  address = "10.0.30.9";
  backendPort = 8222;
  tlsDir = "/var/lib/nginx-tls";
  caddy = "lab_proxy.home.arpa";
in
{
  services.vaultwarden = {
    enable = true;
    inherit domain;
    environmentFile = config.sops.secrets."vaultwarden/adminToken".path;
    config = {
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = backendPort;
      ENABLE_WEBSOCKET = true;
    };
  };

  sops.secrets."vaultwarden/adminToken" = { };


  systemd.services.nginx-selfsigned-cert = {
    description = "Self-signed TLS certificate for ${domain}";
    before = [ "nginx.service" ];
    requiredBy = [ "nginx.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = config.services.nginx.user;
      Group = config.services.nginx.group;
      StateDirectory = "nginx-tls";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };

    script = ''
      [ -s ${tlsDir}/cert.pem ] && [ -s ${tlsDir}/key.pem ] && exit 0

      ${pkgs.openssl}/bin/openssl req -x509 -nodes -days 3650 \
        -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -subj "/CN=${domain}" \
        -addext "subjectAltName=DNS:${domain},IP:${address}" \
        -addext "basicConstraints=critical,CA:TRUE" \
        -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
        -addext "extendedKeyUsage=serverAuth" \
        -keyout ${tlsDir}/key.pem -out ${tlsDir}/cert.pem

      chmod 0400 ${tlsDir}/key.pem
      chmod 0444 ${tlsDir}/cert.pem
    '';
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "525m";

    commonHttpConfig = ''
      set_real_ip_from ${caddy};
      real_ip_header X-Forwarded-For;
      real_ip_recursive on;
    '';

    upstreams.vaultwarden.servers."127.0.0.1:${toString backendPort}" = { };

    virtualHosts.${domain} = {
      onlySSL = true;
      sslCertificate = "${tlsDir}/cert.pem";
      sslCertificateKey = "${tlsDir}/key.pem";

      locations = {
        "/".proxyPass = "http://vaultwarden";
        "= /notifications/hub" = {
          proxyPass = "http://vaultwarden";
          proxyWebsockets = true;
        };
        "= /notifications/anonymous-hub" = {
          proxyPass = "http://vaultwarden";
          proxyWebsockets = true;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
}
