{ pkgs ? import <nixpkgs> {} }:

rec {
  thcrap-wrapper = pkgs.callPackage ./pkgs/misc/steam/thcrap-wrapper {};
  np2kai = pkgs.callPackage ./pkgs/misc/emulators/np2kai {};
}