{ ... }:
{
  services.glance = {
    enable = true;
    openFirewall = true;
    settings = {
      server = {
        host = "0.0.0.0";
        port = 8080;
      };
      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                { type = "calendar"; }
                { type = "weather"; location = "Orlando, Florida, United States"; units = "imperial"; }
              ];
            }
            {
              size = "full";
              widgets = [
                { type = "hacker-news"; }
                { type = "releases"; repositories = [ "glanceapp/glance" "NixOS/nixpkgs" ]; }
              ];
            }
          ];
        }
      ];
    };
  };
}
