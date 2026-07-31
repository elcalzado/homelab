{ config, pkgs, ... }:

let
  domain = "vaultwarden.guster.xyz";
  backendPort = 8222;
  tlsDir = "/var/lib/nginx-tls";
  caddySource = "10.0.30.1";
  adminSubnet = "10.0.100.0/28";
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
    };
  };

  sops.secrets."vaultwarden/adminToken" = {
    restartUnits = [ "vaultwarden.service" ];
  };

  systemd.services.vaultwarden-nginx-cert = {
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
      if [ -s ${tlsDir}/cert.pem ] && [ -s ${tlsDir}/key.pem ] \
        && [ "$(cat ${tlsDir}/subject 2>/dev/null)" = "${domain}" ] \
        && ${pkgs.openssl}/bin/openssl x509 -in ${tlsDir}/cert.pem -checkend 2592000 -noout
      then
        exit 0
      fi

      rm -f ${tlsDir}/cert.pem ${tlsDir}/key.pem ${tlsDir}/subject

      ${pkgs.openssl}/bin/openssl req -x509 -nodes -days 3650 \
        -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -subj "/CN=${domain}" \
        -addext "subjectAltName=DNS:${domain}" \
        -addext "basicConstraints=critical,CA:TRUE" \
        -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
        -addext "extendedKeyUsage=serverAuth" \
        -keyout ${tlsDir}/key.pem -out ${tlsDir}/cert.pem

      printf '%s' "${domain}" > ${tlsDir}/subject
      chmod 0400 ${tlsDir}/key.pem
      chmod 0444 ${tlsDir}/cert.pem
    '';
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "525m";

    commonHttpConfig = ''
      set_real_ip_from ${caddySource};
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
        "^~ /admin" = {
          proxyPass = "http://vaultwarden";
          extraConfig = ''
            allow ${adminSubnet};
            deny all;
          '';
        };
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
