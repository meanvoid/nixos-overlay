{
  description = "my overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
        ];
        config = { allowUnfree = true; };
      };
    in {
      overlays.default =  (final: prev: rec {
        thcrap = final.callPackage ./pkgs/misc/steam/thcrap-wrapper {};
        np2kai = final.callPackage ./pkgs/misc/emulators/np2kai {};
      });
      packages.${system}.default = pkgs.callPackage ./default.nix {};
    };
}