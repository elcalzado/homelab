_:

let
  dynamicUserStateDir = "/var/lib/private/seerr";
in
{
  # Web UI on :5055
  services.seerr = {
    enable = true;
    openFirewall = true;
  };

  homelab.backup.jobs.seerr = {
    at = "02:40";
    databases = [ { engine = "sqlite"; path = "${dynamicUserStateDir}/db/db.sqlite3"; } ];
    files = [ "${dynamicUserStateDir}/settings.json" ];
  };
}
