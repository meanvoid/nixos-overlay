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
  }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    overlayAttrs = config.packages;
    packages = {
      crossover = pkgs.callPackage ./games/crossover {
        fhsenv = (pkgs.callPackage ./games/crossover/fhsenv.nix {}).override;
        unwrapped = pkgs.callPackage ./games/crossover/unwrapped.nix {};
      };
      crossover-test = pkgs.callPackage ./games/crossover/test.nix {};
      crossover-test2 = pkgs.callPackage ./games/crossover/test2.nix {};
      thcrap-proton = pkgs.callPackage ./games/steam/thcrap-proton {};
      anime-cursors = pkgs.callPackage ./cursors/anime-cursors {};
    };
  };
}
