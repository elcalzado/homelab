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

      # For host dir ./hosts/<name>, emit TWO deployables that share the exact
      # same platform-agnostic core, differing only by which adapter is layered on:
      #
      #   <name>-lxc : core + Proxmox-LXC adapter
      #   <name>-vm  : core + VM/baremetal adapter + declarative disko disk layout
      mkHost = channel: name: {
        "${name}-lxc" = mkSystem channel [
          ./hosts/${name}
          ./modules/lxc.nix
        ];
        "${name}-vm" = mkSystem channel [
          ./hosts/${name}
          ./modules/vm.nix
          ./modules/disk.nix
        ];
      };
    in {
      nixosConfigurations =
        (mkHost nixpkgs "glance")
        // (mkHost nixpkgs "qbittorrent")
        // (mkHost nixpkgs "omada")
        // (mkHost nixpkgs "servarr")
        // (mkHost nixpkgs "jellyfin")
        // (mkHost nixpkgs-unstable "immich")
        // (mkHost nixpkgs "portainer");
    };
}
