{
  description = "Collection of random packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-hooks-nix.url = "github:cachix/pre-commit-hooks.nix";
    devshell.url = "github:numtide/devshell";
    frida.url = "github:itstarsun/frida-nix";
  };

  outputs = {self, ...} @ inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      flake.nixosModules = let
        inherit (inputs.nixpkgs) lib;
        pkgs = import (inputs.nixpkgs);
      in {
        nvidiaVgpu = import ./modules/vgpu/default.nix {
          # frida = inputs.frida.packages.${pkgs.system}.frida-tools;
          vgpu_unlock = pkgs.callPackage ./modules/vgpu/vgpu_unlock.nix {};
          compile-driver = pkgs.callPackage ./modules/vgpu/compile-driver.nix {};
        };
        default = throw (lib.mdDoc ''
          The usage of default module is deprecated
          ${builtins.concatStringsSep "\n" (lib.filter (name: name != "default") (lib.attrNames self.nixosModules))}
        '');
      };

      imports = [
        inputs.pre-commit-hooks-nix.flakeModule
        inputs.devshell.flakeModule
        ./pkgs
      ];

      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;
        devshells.default = {
          packages = with pkgs; [
            alejandra
            bintools
            findutils
            pciutils
            lshw
            nix-index
            nix-prefetch-github
            nix-prefetch-scripts
          ];
        };
      };
    };
}
