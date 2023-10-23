{ pkgs ? import <nixpkgs> {} }:

rec {
  thcrap-wrapper = pkgs.callPackage ./pkgs/misc/thcrap-wrapper {};
}