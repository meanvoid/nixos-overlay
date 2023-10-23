{ pkgs ? import <nixpkgs> {} }:

rec {
  thcrap-wrapper = pkgs.callPackage ./pkgs/misc/thcrap-wrapper {};
  np2kai = pkgs.callPackage ./pkgs/emulators/np2kai {};
}