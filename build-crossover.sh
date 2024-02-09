#!/usr/bin/env bash

NIXPKGS_ALLOW_UNFREE=1 nix-build -E 'with import <nixpkgs> { }; callPackage ./pkgs/games/crossover {
  fhsenv = (callPackage ./pkgs/games/crossover/fhsenv.nix {}).override;
  unwrapped = callPackage ./pkgs/games/crossover/unwrapped.nix {};
}'

./result/bin/crossover