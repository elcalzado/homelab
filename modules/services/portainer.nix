{ config, ... }:

let
  domain = "portainer.guster.xyz";
  stateDir = "/var/lib/portainer";
  dataDir = "${stateDir}/data";
  adminPasswordFile = "/run/portainer-admin-password";
in
{
  sops = {
    secrets."webui/adminPassword" = { };
    secrets."portainerAgent/secret" = { };

    templates."portainer.env".content = ''
      AGENT_SECRET=${config.sops.placeholder."portainerAgent/secret"}
    '';
  };

  virtualisation = {
    podman.enable = true;

    oci-containers.containers.portainer = {
      image = "portainer/portainer-ce:2.39.5";
      autoStart = true;
      ports = [
        "9443:9443"
      ];
      volumes = [
        "${dataDir}:/data"
        "${config.sops.secrets."webui/adminPassword".path}:${adminPasswordFile}:ro"
      ];
      environmentFiles = [ config.sops.templates."portainer.env".path ];
      cmd = [
        "--trusted-origins=${domain}"
        "--admin-password-file=${adminPasswordFile}"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 root root -"
    "d ${dataDir}  0700 root root -"
  ];

  homelab.backup.jobs.portainer = {
    at = "01:00";
    trees = [ dataDir ];
  };
}
