{
  description = "my overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs {
        config = { allowUnfree = true; };
      };
    in {
      overlays = [
        (final: prev: rec {
          thcrap-wrapper = final.callPackage ./pkgs/misc/thcrap-wrapper {};
        })
      ];
      packages = pkgs;
    };
}
