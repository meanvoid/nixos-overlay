{
  lib,
  stdenv,
  fetchurl,
  runtimeShell,
  traceDeps ? false,
  bash,
  dpkg,
  pkgs,
}: let
  version = "23.7.1";
in
  stdenv.mkDerivation {
    pname = "crossover-original";
    inherit version;

    src = fetchurl {
      # use archive url so the tarball doesn't 404 on a new release
      url = "https://media.codeweavers.com/pub/crossover/cxlinux/demo/crossover_${version}-1.deb";
      sha256 = "sha256-aTEakY9IiPd3oLmuV+f8ecyqrj+9Y8/0yNJCdC2H64E=";
    };

    nativeBuildInputs = [
      dpkg
    ];

    buildInputs = [
      pkgs.gtk3
      pkgs.vte
      pkgs.gnome.zenity
      (pkgs.python3.withPackages (p:
        with p; [
          pygobject3
          gst-python
          dbus-python
          pycairo
        ]))
    ];

    unpackCmd = "dpkg -x $src source";

    postInstall = ''
      mkdir -p $out/opt
      mv opt $out/opt

      mv usr $out/usr
    '';

    meta = with lib; {
      description = "Run your Windows® app on MacOS, Linux, or ChromeOS";
      longDescription = ''
        Run Windows Applications Without Rebooting.
      '';
      homepage = "https://www.codeweavers.com/crossover/";
      license = licenses.unfreeRedistributable;
      mainProgram = "crossover";
    };
  }
