{
  inputs,
  self,
  ...
}: {
  systems = ["x86_64-linux"];

  imports = [inputs.flake-parts.flakeModules.easyOverlay];

  perSystem = {
    config,
    system,
    pkgs,
    ...
  } @ args: let
    overlayAttrs = config.packages;
  in {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    overlayAttrs = config.packages;
    packages = {
      crossover-deprecated = pkgs.callPackage ./games/crossover/deprecated.nix {};
      crossover-unwrapped = pkgs.callPackage ./games/crossover/unwrapped.nix {};
      crossover = pkgs.callPackage ./games/crossover/fhsenv.nix {
        inherit (overlayAttrs) crossover-unwrapped;
      };
      thcrap-proton = pkgs.callPackage ./games/steam/thcrap-proton {};
      anime-cursors = pkgs.callPackage ./cursors/anime-cursors {};

      vgpu_unlock = pkgs.callPackage ../modules/vgpu/vgpu_unlock.nix {};
      compile-driver = pkgs.callPackage ../modules/vgpu/compile-driver.nix {};
      gradience-git = pkgs.callPackage ./misc/gradience-git {};
    };
  };
}
