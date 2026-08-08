{
  description = "Homelab NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-unstable, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      mkSystem = channel: system: modules:
        channel.lib.nixosSystem {
          modules = modules ++ [ { nixpkgs.hostPlatform = system; } ];
          specialArgs = { inherit inputs; };
        };

      platforms = {
        lxc = [ ./modules/lxc.nix ];
        vm = [ ./modules/vm.nix ./modules/disk.nix ];
      };

      targets = {
        amd64-lxc = { system = "x86_64-linux"; modules = platforms.lxc; };
        amd64-vm = { system = "x86_64-linux"; modules = platforms.vm; };
        arm64-lxc = { system = "aarch64-linux"; modules = platforms.lxc; };
        arm64-vm = { system = "aarch64-linux"; modules = platforms.vm; };
      };

      mkHost = channel: name: names:
        lib.listToAttrs (map
          (target: lib.nameValuePair "${name}-${target}"
            (mkSystem channel targets.${target}.system ([ ./hosts/${name} ] ++ targets.${target}.modules)))
          names);

      hosts =
        (mkHost nixpkgs "glance" [ "amd64-lxc" "amd64-vm" ])
        // (mkHost nixpkgs "qbittorrent" [ "amd64-vm" ])
        // (mkHost nixpkgs "omada" [ "amd64-lxc" "amd64-vm" ])
        // (mkHost nixpkgs "servarr" [ "amd64-vm" ])
        // (mkHost nixpkgs "jellyfin" [ "amd64-vm" ])
        // (mkHost nixpkgs-unstable "immich" [ "amd64-vm" ])
        // (mkHost nixpkgs "portainer" [ "amd64-lxc" "amd64-vm" ])
        // (mkHost nixpkgs "gatus" [ "amd64-lxc" "amd64-vm" ])
        // (mkHost nixpkgs "runner" [ "amd64-lxc" ])
        // (mkHost nixpkgs "builder" [ "amd64-vm" ]);
    in {
      nixosConfigurations = hosts;

      # `nix flake check` builds every host, so a config that evaluates but does
      # not build fails here rather than on the machine.
      checks = lib.mapAttrs
        (_: names: lib.genAttrs names (name: hosts.${name}.config.system.build.toplevel))
        (lib.groupBy (name: hosts.${name}.config.nixpkgs.hostPlatform.system) (lib.attrNames hosts));
    };
}
