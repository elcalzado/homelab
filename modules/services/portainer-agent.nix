{ config, ... }:

let
  volumeDir = "/var/lib/containers/storage/volumes";
in
{
  virtualisation = {
    podman.enable = true;

    oci-containers.containers.portainer-agent = {
      image = "portainer/agent:2.39.5";
      autoStart = true;
      ports = [
        "9001:9001"
      ];
      volumes = [
        "/run/podman/podman.sock:/var/run/docker.sock"
        "${volumeDir}:/var/lib/docker/volumes"
        "/:/host"
      ];
      environmentFiles = [ config.sops.templates."portainer-agent.env".path ];
    };
  };

  sops = {
    secrets."portainerAgent/secret" = { };

    templates."portainer-agent.env".content = ''
      AGENT_SECRET=${config.sops.placeholder."portainerAgent/secret"}
    '';
  };

  homelab.backup.jobs."${config.networking.hostName}-portainer" = {
    at = "01:10";
    trees = [
      volumeDir
    ];
  };
}
