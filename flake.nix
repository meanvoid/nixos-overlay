{
  description = "Collection of random packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    devshell.url = "github:numtide/devshell";
  };

  outputs = {
    self,
    pre-commit-hooks,
    ...
  } @ inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];
      imports = [inputs.flake-parts.flakeModules.easyOverlay];
      flake.nixosModules = let
        inherit (inputs.nixpkgs) lib;
      in {
        default = throw (lib.mdDoc ''
          The usage of default module is deprecated
          ${builtins.concatStringsSep "\n" (lib.filter (name: name != "default") (lib.attrNames self.nixosModules))}
        '');
        nvidia-vGPU = import ./modules/vgpu/default.nix;
        kvmfr = import ./modules/kvmfr/default.nix;
      };
      perSystem = {
        config,
        system,
        pkgs,
        ...
      }: {
        _module.args.pkgs = builtins.trace "Current system: ${system}" import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          programs.nix-ld.enable = true;
          overlays = [
            inputs.devshell.overlays.default
          ];
        };
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks.alejandra.enable = true; # enable pre-commit formatter
          };
        };
        devShells.default = let
          inherit (config.checks.pre-commit-check) shellHook;
        in
          pkgs.devshell.mkShell {
            imports = [(pkgs.devshell.importTOML ./devshell.toml)];
            git.hooks = {
              enable = true;
              pre-commit.text = shellHook;
            };
          };
        formatter = pkgs.alejandra;

        packages = {
          thcrap-proton = pkgs.callPackage ./pkgs/games/steam/thcrap-proton {};
          anime-cursors = pkgs.callPackage ./pkgs/cursors/anime-cursors {};

          vgpu_unlock = pkgs.callPackage ../pkgs/modules/vgpu/vgpu_unlock.nix {};
          compile-driver = pkgs.callPackage ../pkgs/modules/vgpu/compile-driver.nix {};
        };
      };
    };
}
