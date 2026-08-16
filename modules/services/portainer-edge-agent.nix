{ config, ... }:

let
  stateDir = "/var/lib/portainer-edge-agent";
  dataDir = "${stateDir}/data";
in
{
  virtualisation = {
    podman.enable = true;

    oci-containers.containers.portainer-edge-agent = {
      image = "portainer/agent:2.39.5";
      autoStart = true;
      volumes = [
        "${dataDir}:/data"
        "/run/podman/podman.sock:/var/run/docker.sock"
        "/var/lib/containers/storage/volumes:/var/lib/docker/volumes"
        "/:/host"
      ];
      environment = {
        EDGE = "1";
        EDGE_INSECURE_POLL = "1";
      };
      environmentFiles = [ config.sops.templates."portainer-edge-agent.env".path ];
    };
  };

  sops = {
    secrets."edgeAgent/id" = { };
    secrets."edgeAgent/key" = { };

    templates."portainer-edge-agent.env".content = ''
        EDGE_ID=${config.sops.placeholder."edgeAgent/id"}
        EDGE_KEY=${config.sops.placeholder."edgeAgent/key"}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 root root -"
    "d ${dataDir}  0700 root root -"
  ];

  homelab.backup.jobs.portainer-edge-agent = {
    at = "01:10";
    trees = [ dataDir ];
  };
}