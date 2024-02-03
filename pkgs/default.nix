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
      crossover = pkgs.callPackage ./games/crossover/crossover.nix {};
      crossover-fhsenv = pkgs.callPackage ./games/crossover/fhsenv.nix {
        inherit (config.packages) crossover;
      };
      thcrap-proton = pkgs.callPackage ./games/steam/thcrap-proton {};
      anime-cursors = pkgs.callPackage ./cursors/anime-cursors {};
    };
  };
}
