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
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { nixpkgs, nixpkgs-unstable, deploy-rs, ... }@inputs:
  let
    inherit (nixpkgs) lib;

    channels = {
      stable = nixpkgs;
      unstable = nixpkgs-unstable;
    };

    mkSystem = channel: system: modules: targetConfig:
      channel.lib.nixosSystem {
        modules = modules ++ [ { nixpkgs.hostPlatform = system; } ];
        specialArgs = { inherit inputs targetConfig; };
      };

    platforms = {
      lxc = [ ./modules/lxc.nix ];
      vm = [ ./modules/vm.nix ];
      pc = [ ./modules/pc.nix ];
      pi = [ ./modules/pi.nix ];
    };

    targetSpecs = {
      amd64-lxc = { system = "x86_64-linux"; modules = platforms.lxc; };
      amd64-vm = { system = "x86_64-linux"; modules = platforms.vm; };
      amd64-pc = { system = "x86_64-linux"; modules = platforms.pc; };
      arm64-lxc = { system = "aarch64-linux"; modules = platforms.lxc; };
      arm64-vm = { system = "aarch64-linux"; modules = platforms.vm; };
      arm64-pc = { system = "aarch64-linux"; modules = platforms.pc; };
      arm64-pi = { system = "aarch64-linux"; modules = platforms.pi; };
    };

    hostNames = lib.filter
      (name: builtins.pathExists (./hosts + "/${name}/meta.nix"))
      (lib.attrNames
        (lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./hosts)));

    hostMeta = lib.genAttrs hostNames (name:
      let
        meta = import ./hosts/${name}/meta.nix;
      in
      if builtins.isAttrs meta
      then meta
      else throw "hosts/${name}/meta.nix must evaluate to a plain attrset, not a function or other value"
    );

    mkHost = name:
      let
        meta = hostMeta.${name};
      in
      lib.mapAttrs'
        (target: targetConfig:
          let
            spec = targetSpecs.${target};
          in
          lib.nameValuePair
            "${name}-${target}"
            (mkSystem channels.${targetConfig.channel} spec.system
              ([ ./hosts/${name} ] ++ spec.modules)
              targetConfig))
        meta.targets;

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
