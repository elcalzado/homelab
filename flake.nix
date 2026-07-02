{
  description = "Homelab NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";

      mkSystem = modules:
        nixpkgs.lib.nixosSystem {
          inherit system modules;
          specialArgs = { inherit inputs; };
        };

      # For host dir ./hosts/<name>, emit TWO deployables that share the exact
      # same platform-agnostic core, differing only by which adapter is layered on:
      #
      #   <name>-lxc : core + Proxmox-LXC adapter
      #   <name>-vm  : core + VM/baremetal adapter + that machine's generated hardware config
      mkHost = name: {
        "${name}-lxc" = mkSystem [
          ./hosts/${name}
          ./modules/lxc.nix
        ];
        "${name}-vm" = mkSystem [
          ./hosts/${name}
          ./modules/vm.nix
          ./hosts/${name}/hardware-configuration.nix
        ];
      };
    in {
      nixosConfigurations =
        (mkHost "glance")
        // (mkHost "qbittorrent");
    };
}
