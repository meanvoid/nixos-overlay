{
  description = "Collection of random packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    nixpkgs-python.url = "github:cachix/nixpkgs-python";
    nix2container.url = "github:nlewo/nix2container";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";

    devenv.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-python.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      flake-parts,
      flake-utils,
      devenv,
      pre-commit-hooks,
      ...
    }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devenv.flakeModule ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      flake.nixosModules =
        let
          inherit (inputs.nixpkgs) lib;
        in
        {
          default = throw (
            lib.mdDoc ''
              The usage of default module is deprecated
              ${builtins.concatStringsSep "\n" (lib.filter (name: name != "default") (lib.attrNames self.nixosModules))}
            ''
          );
          nvidia-vgpu = import ./modules/vgpu/default.nix;
        };
      perSystem =
        {
          config,
          system,
          pkgs,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          checks = {
            pre-commit-check = pre-commit-hooks.lib.${system}.run {
              ## --- NIX related hooks --- ##
              # formatter
              hooks.nixfmt-rfc-style = {
                enable = true;
                excludes = [
                  ".direnv"
                  ".devenv"
                ];
                settings.width = 120;
                package = pkgs.nixfmt-rfc-style;
              };
              ## --- NIX related hooks --- ##
            };
          };
          devenv.shells.default = {
            name = "Flake Environment";
            languages = {
              nix.enable = true;
              shell.enable = true;
              # python = {
              #   enable = true;
              #   venv = {
              #     enable = true;
              #     requirements = ''
              #       black
              #       isort
              #       mypy
              #       flake8
              #     '';
              #   };
              #   version = "3.11";
              # };
            };
            pre-commit = {
              excludes = [
                ".direnv"
                ".devenv"
              ];
              hooks.nixfmt-rfc-style = {
                enable = true;
                excludes = [
                  ".direnv"
                  ".devenv"
                  "pkgs"
                ];
                settings.width = 120;
                package = pkgs.nixfmt-rfc-style;
              };
              hooks.black = {
                enable = true;
                excludes = [
                  ".direnv"
                  ".devenv"
                ];
                files = ".py";
              };
              hooks.isort = {
                enable = true;
                excludes = [
                  ".direnv"
                  ".devenv"
                ];
                files = ".py";
              };
              hooks.flake8 = {
                enable = true;
                excludes = [
                  ".direnv"
                  ".devenv"
                ];
                args = [ "--max-line-length=120" ];
                files = ".py";
              };
              hooks.shellcheck.enable = true;
            };
            packages = builtins.attrValues {
              inherit (pkgs) git pre-commit;
              inherit (pkgs) nix-index nix-prefetch-github nix-prefetch-scripts;
            };
          };
          formatter = pkgs.nixfmt-rfc-style;

          packages = {
            anime-cursors = pkgs.callPackage ./pkgs/cursors/anime-cursors { };

            # nvidia vgpu
            compile-driver = pkgs.callPackage /modules/vgpu/compile-driver.nix { };
          };
        };
    };
}
