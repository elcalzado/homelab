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

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      deploy-rs,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      channels = {
        stable = nixpkgs;
        unstable = nixpkgs-unstable;
      };

      mkSystem =
        channel: system: modules: targetConfig:
        channel.lib.nixosSystem {
          modules = modules ++ [ { nixpkgs.hostPlatform = system; } ];
          specialArgs = { inherit inputs targetConfig; };
        };

      systemOf = cfg: cfg.config.nixpkgs.hostPlatform.system;

      platforms = {
        lxc = [ ./modules/lxc.nix ];
        vm = [ ./modules/vm.nix ];
        pc = [ ./modules/pc.nix ];
        rpi = [ ./modules/rpi.nix ];
      };

      targetSpecs = {
        amd64-lxc = {
          system = "x86_64-linux";
          modules = platforms.lxc;
        };
        amd64-vm = {
          system = "x86_64-linux";
          modules = platforms.vm;
        };
        amd64-pc = {
          system = "x86_64-linux";
          modules = platforms.pc;
        };
        arm64-lxc = {
          system = "aarch64-linux";
          modules = platforms.lxc;
        };
        arm64-vm = {
          system = "aarch64-linux";
          modules = platforms.vm;
        };
        arm64-pc = {
          system = "aarch64-linux";
          modules = platforms.pc;
        };
        arm64-rpi = {
          system = "aarch64-linux";
          modules = platforms.rpi;
        };
      };

      isDirectory = _name: type: type == "directory";
      hasMetaFile = name: builtins.pathExists (./hosts + "/${name}/meta.nix");
      isRealHost = name: hasMetaFile name && name != "archived";

      hostNames = lib.filter isRealHost (
        lib.attrNames (lib.filterAttrs isDirectory (builtins.readDir ./hosts))
      );

      loadHostMeta =
        name:
        let
          meta = import ./hosts/${name}/meta.nix;
        in
        if builtins.isAttrs meta then
          meta
        else
          throw "hosts/${name}/meta.nix must evaluate to a plain attrset, not a function or other value";

      hostMeta = lib.genAttrs hostNames loadHostMeta;

      mkHost =
        name:
        let
          meta = hostMeta.${name};
        in
        lib.mapAttrs' (
          target: targetConfig:
          let
            spec = targetSpecs.${target};
          in
          lib.nameValuePair "${name}-${target}" (
            mkSystem channels.${targetConfig.channel} spec.system (
              [ ./hosts/${name} ] ++ spec.modules
            ) targetConfig
          )
        ) meta.targets;

      hosts = lib.foldl' (acc: name: acc // mkHost name) { } hostNames;

      backupJobNamesOf = host: lib.attrNames (host.config.homelab.backup.jobs or { });

      allBackupJobs = lib.unique (lib.concatLists (lib.mapAttrsToList (_: backupJobNamesOf) hosts));

      primaryAddressOf =
        cfg:
        let
          interface = cfg.config.networking.defaultGateway.interface;
        in
        (lib.head cfg.config.networking.interfaces.${interface}.ipv4.addresses).address;

      mkNode =
        output:
        let
          cfg = hosts.${output};
        in
        {
          hostname = primaryAddressOf cfg;
          sshUser = "deploy";
          autoRollback = true;
          magicRollback = true;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${systemOf cfg}.activate.nixos cfg;
          };
        };

      nodes = lib.genAttrs hostNames (
        name:
        let
          meta = hostMeta.${name};
          target = meta.defaultTarget or (lib.head (lib.attrNames meta.targets));
        in
        mkNode "${name}-${target}"
      );

      hostsBySystem = lib.groupBy (name: systemOf hosts.${name}) (lib.attrNames hosts);

      toplevelChecksFor = names: lib.genAttrs names (name: hosts.${name}.config.system.build.toplevel);
    in
    {
      nixosConfigurations = hosts;

      deploy = { inherit nodes; };

      backupJobs = allBackupJobs;

      checks = lib.mapAttrs (
        system: names: toplevelChecksFor names // deploy-rs.lib.${system}.deployChecks { inherit nodes; }
      ) hostsBySystem;
    };
}
