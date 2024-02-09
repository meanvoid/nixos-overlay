{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  writeShellScriptBin,
  pkgs,
  steam,
  wrapGAppsHook,
  gobject-introspection,
  glibc_multi,
  gsettings-desktop-schemas,
  python3Packages,
}: let
  gds = gsettings-desktop-schemas;
  fakePkExec = writeShellScriptBin "pkexec" ''
    declare -a final
    for value in "$@"; do
      final+=("$value")
    done
    exec "''${final[@]}"
  '';
  steam-run =
    (steam.override {
      extraPkgs = p:
        with p; [
        ];
      extraLibraries = p:
        with p; [
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
      extraProfile = ''
        export PATH=${fakePkExec}/bin:$PATH
      '';
    })
    .run;

  version = "23.7.1-1";
in
  stdenv.mkDerivation rec {
    pname = "crossover";
    inherit version;

    buildInputs = [
      steam-run
      pkgs.gtkdialog
      pkgs.gtk3
      pkgs.vte
      pkgs.sane-backends
      pkgs.libgphoto2
      pkgs.ocl-icd
      pkgs.alsa-lib
      pkgs.pulseaudio
      pkgs.libxcrypt-legacy
      pkgs.gst_all_1.gstreamer
      pkgs.gst_all_1.gst-plugins-good
      pkgs.gst_all_1.gst-plugins-ugly
      pkgs.gst_all_1.gst-plugins-base
      (pkgs.python3.withPackages (p:
        with p; [
          pygobject3
          gst-python
          dbus-python
          pycairo
        ]))
    ];

    src = fetchurl {
      url = "https://media.codeweavers.com/pub/crossover/cxlinux/demo/crossover_${version}.deb";
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

    meta = with lib; {
      description = "Run your Windows® app on MacOS, Linux, or ChromeOS";
      maintainers = with maintainers; [yswtrue];
      license = licenses.gpl3Only;
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      platforms = ["x86_64-linux"];
    };
  }
