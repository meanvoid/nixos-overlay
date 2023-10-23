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
      thcrap-proton = pkgs.callPackage ./steam/thcrap-proton {};
      anime-cursors = pkgs.callPackage ./cursors/anime-cursors {};
    };
  };
}
