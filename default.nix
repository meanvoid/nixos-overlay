{ pkgs ? import <nixpkgs> {} }:

rec {
  thcrap-wrapper = pkgs.callPackage ./pkgs/misc/steam/thcrap-wrapper {};
}