_:

let
  dynamicUserStateDir = "/var/lib/private/prowlarr";
in
{
  # Web UI on :9696
  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  homelab.backup.jobs.prowlarr = {
    at = "02:20";
    databases = [ "${dynamicUserStateDir}/prowlarr.db" ];
    files = [ "${dynamicUserStateDir}/config.xml" ];
  };
}
