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
      system = "x86_64-linux";

      mkSystem = channel: modules:
        channel.lib.nixosSystem {
          inherit system modules;
          specialArgs = { inherit inputs; };
        };

      targets = {
        lxc = [ ./modules/lxc.nix ];
        vm = [ ./modules/vm.nix ./modules/disk.nix ];
      };

      mkHost = channel: name: names:
        nixpkgs.lib.listToAttrs (map
          (target: nixpkgs.lib.nameValuePair "${name}-${target}"
            (mkSystem channel ([ ./hosts/${name} ] ++ targets.${target})))
          names);
      hosts =
        (mkHost nixpkgs "glance" [ "lxc" "vm" ])
        // (mkHost nixpkgs "qbittorrent" [ "vm" ])
        // (mkHost nixpkgs "omada" [ "lxc" "vm" ])
        // (mkHost nixpkgs "servarr" [ "vm" ])
        // (mkHost nixpkgs "jellyfin" [ "vm" ])
        // (mkHost nixpkgs-unstable "immich" [ "vm" ])
        // (mkHost nixpkgs "portainer" [ "lxc" "vm" ])
        // (mkHost nixpkgs "gatus" [ "lxc" "vm" ]);
    in {
      nixosConfigurations = hosts;

      # `nix flake check` builds every host, so a config that evaluates but does
      # not build fails here rather than on the machine.
      checks.${system} = nixpkgs.lib.mapAttrs'
        (name: cfg: nixpkgs.lib.nameValuePair name cfg.config.system.build.toplevel)
        hosts;
    };
}
