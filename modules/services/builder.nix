_:

{
  nix = {
    settings = {
      trusted-users = [ "nixbuilder" ];
      max-jobs = "auto";
      cores = 0;
    };

    gc = {
      automatic = true;
      dates = "03:15";
      options = "--delete-older-than 30d";
    };
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  users.users.nixbuilder = {
    isNormalUser = true;
    group = "nixbuilder";
  };

  users.groups.nixbuilder = { };
}
