{
  lib,
  fetchurl,
  stdenv,
  runtimeShell,
  traceDeps ? true,
  dpkg,
  glibc_multi,
  wrapGAppsHook,
  gobject-introspection,
  gtkdialog,
  gtk3,
  vte,
  python3Packages,
  steam,
  steam-run,
  gsettings-desktop-schemas,
  customIcon ? null,
}: let
  gds = gsettings-desktop-schemas;
  version = "23.7.1";

  steam-run = (steam.override {
    extraLibraries = pkgs: with pkgs; [
      gnutls
      openldap
      gmp
      openssl
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-plugins-base
      libunwind
      sane-backends
      libgphoto2
      openal
      apulse

      libpcap
      sane-backends
      ocl-icd
      libxcrypt-legacy
    ];
  }).run;
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
        dpkg
        glibc_multi
        wrapGAppsHook
        gobject-introspection
      ];

      buildInputs = with python3Packages;
        [
          pygobject3
          gst-python
          dbus-python
          pycairo
        ]
        ++ [
          gtkdialog
          gtk3
          vte
          steam-run
          python
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

        makeWrapper ${steam-run}/bin/steam-run $out/bin/crossover \
          --add-flags $out/opt/cxoffice/bin/crossover \
          --set-default GSETTINGS_SCHEMA_DIR "${gds}/share/gsettings-schemas/${gds.pname}-${gds.version}/glib-2.0/schemas"

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
