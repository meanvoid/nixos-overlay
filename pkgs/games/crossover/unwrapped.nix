{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  pkgs,
  steam-run,
  wrapGAppsHook,
  gobject-introspection,
  glibc_multi,
  gsettings-desktop-schemas,
  customIcon ? null,
}: let
  gds = gsettings-desktop-schemas;
  version = "23.7.1";
in
  with lib;
    stdenv.mkDerivation {
      pname = "crossover";
      inherit version;

      src = fetchurl {
        url = "https://media.codeweavers.com/pub/crossover/cxlinux/demo/crossover_${version}-1.deb";
        sha256 = "sha256-aTEakY9IiPd3oLmuV+f8ecyqrj+9Y8/0yNJCdC2H64E=";
      };

      nativeBuildInputs = [
        glibc_multi
        autoPatchelfHook
        wrapGAppsHook
        gobject-introspection
        makeWrapper
        dpkg
      ];
      autoPatchelfIgnoreMissingDeps = [
        "libpcap.so.0.8"
        "libcapi20.so.3"
      ];

      buildInputs = [
        steam-run
        pkgs.gtkdialog
        pkgs.gtk3
        pkgs.vte
        pkgs.libgphoto2
        pkgs.sane-backends
        pkgs.ocl-icd
        pkgs.pkgs.alsa-lib
        pkgs.pulseaudio
        pkgs.libxcrypt-legacy
        pkgs.gst_all_1.gstreamer
        pkgs.gst_all_1.gst-plugins-base
        pkgs.gst_all_1.gst-plugins-good
        pkgs.gst_all_1.gst-plugins-ugly
        (pkgs.python310.withPackages (p:
          with p; [
            pygobject3
            gst-python
            dbus-python
            pycairo
          ]))
      ];
      format = "other";
      dontWrapGApps = true;

      unpackCmd = "dpkg -x $src source";

      preFixup = ''
        makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
      '';

      installPhase = ''
        mkdir -p $out/opt
        mv opt/* $out/opt/
        mv usr $out/usr

        runHook preFixup
        runHook postInstall
      '';

      postInstall = ''
        rmdir $out/opt/cxoffice/etc
        ln -s /etc/cxoffice/license.txt $out/opt/cxoffice
        ln -s /etc/cxoffice $out/opt/cxoffice/etc
      '';

      passthru = {inherit version customIcon;};
    }
# makeWrapper $out/bin/crossover \
#    --add-flags $out/opt/cxoffice/bin/crossover \
#   --set-default GSETTINGS_SCHEMA_DIR "${gds}/share/gsettings-schemas/${gds.pname}-${gds.version}/glib-2.0/schemas"

