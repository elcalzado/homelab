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

    channels = {
      stable = nixpkgs;
      unstable = nixpkgs-unstable;
    };

    mkSystem = channel: system: modules:
      channel.lib.nixosSystem {
        modules = modules ++ [ { nixpkgs.hostPlatform = system; } ];
        specialArgs = { inherit inputs; };
      };

    platforms = {
      lxc = [ ./modules/lxc.nix ];
      vm = [ ./modules/vm.nix ];
    };

    targetSpecs = {
      amd64-lxc = { system = "x86_64-linux"; modules = platforms.lxc; };
      amd64-vm = { system = "x86_64-linux"; modules = platforms.vm; };
      arm64-lxc = { system = "aarch64-linux"; modules = platforms.lxc; };
      arm64-vm = { system = "aarch64-linux"; modules = platforms.vm; };
    };

    hostNames = lib.attrNames
      (lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./hosts));

    hostMeta = lib.genAttrs hostNames (name: import ./hosts/${name}/meta.nix);

    mkHost = name:
      let
        meta = hostMeta.${name};
        channel = channels.${meta.channel};
      in
      lib.listToAttrs (map
        (target: lib.nameValuePair "${name}-${target}"
          (mkSystem channel targetSpecs.${target}.system
            ([ ./hosts/${name} ] ++ targetSpecs.${target}.modules)))
        meta.targets);

    hosts = lib.foldl' (acc: name: acc // mkHost name) {} hostNames;

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

    nodes = lib.genAttrs hostNames (name:
      let
        meta = hostMeta.${name};
        target = meta.defaultTarget or (lib.head meta.targets);
      in
      mkNode "${name}-${target}");
  in {
    nixosConfigurations = hosts;

    deploy = { inherit nodes; };

    checks = lib.mapAttrs
      (system: names:
        lib.genAttrs names (name: hosts.${name}.config.system.build.toplevel)
        // deploy-rs.lib.${system}.deployChecks { inherit nodes; })
      (lib.groupBy (name: hosts.${name}.config.nixpkgs.hostPlatform.system) (lib.attrNames hosts));
  };
}
