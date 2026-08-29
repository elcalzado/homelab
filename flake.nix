{
  description = "Homelab NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-unstable, deploy-rs, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      mkSystem = channel: system: modules:
        channel.lib.nixosSystem {
          modules = modules ++ [ { nixpkgs.hostPlatform = system; } ];
          specialArgs = { inherit inputs; };
        };

      platforms = {
        lxc = [ ./modules/lxc.nix ];
        vm = [ ./modules/vm.nix ];
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
        // (mkHost nixpkgs "builder" [ "amd64-vm" ])
        // (mkHost nixpkgs "nextcloud" [ "amd64-vm" ])
        // (mkHost nixpkgs "home-assistant" [ "amd64-lxc" ]);

      mkNode = output:
        let
          cfg = hosts.${output};
          system = cfg.config.nixpkgs.hostPlatform.system;
        in
        {
          hostname = (lib.head cfg.config.networking.interfaces.eth0.ipv4.addresses).address;
          sshUser = "deploy";
          autoRollback = true;
          magicRollback = true;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${system}.activate.nixos cfg;
          };
        };

      nodes = {
        builder = mkNode "builder-amd64-vm";
        gatus = mkNode "gatus-amd64-lxc";
        glance = mkNode "glance-amd64-lxc";
        immich = mkNode "immich-amd64-vm";
        jellyfin = mkNode "jellyfin-amd64-vm";
        omada = mkNode "omada-amd64-lxc";
        portainer = mkNode "portainer-amd64-lxc";
        qbittorrent = mkNode "qbittorrent-amd64-vm";
        runner = mkNode "runner-amd64-lxc";
        servarr = mkNode "servarr-amd64-vm";
        nextcloud = mkNode "nextcloud-amd64-vm";
        home-assistant = mkNode "home-assistant-amd64-lxc";
      };
    in {
      nixosConfigurations = hosts;

      deploy = { inherit nodes; };

      # `nix flake check` builds every host, so a config that evaluates but does
      # not build fails here rather than on the machine.
      checks = lib.mapAttrs
        (system: names:
          lib.genAttrs names (name: hosts.${name}.config.system.build.toplevel)
          // deploy-rs.lib.${system}.deployChecks { inherit nodes; })
        (lib.groupBy (name: hosts.${name}.config.nixpkgs.hostPlatform.system) (lib.attrNames hosts));
    };
}
