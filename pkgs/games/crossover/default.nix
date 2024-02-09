{
  lib,
  steam,
  symlinkJoin,
  writeShellScriptBin,
  stdenv,
  makeDesktopItem,
  makeWrapper,
  gsettings-desktop-schemas,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook,
  gobject-introspection,
  glibc_multi,
  atk,
  cairo,
  gdk-pixbuf,
  gnome,
  gst_all_1,
  librsvg,
  glib,
  libgphoto2,
  gtk3,
  libgda,
  libpeas,
  pango,
  vte,
  sane-backends,
  ocl-icd,
  alsa-lib,
  pulseaudio,
  libxcrypt-legacy,
  python3,
  extraPackages ? pkgs: [],
  extraLibs ? pkgs: [],
}: let
  binName = "crossover";
  desktopName = "Crossover";
  packageName = "crossover";
  version = "23.7.1";

  inherit (gst_all_1) gstreamer gst-plugins-good gst-plugins-ugly gst-plugins-base gst-plugins-bad;
  gds = gsettings-desktop-schemas;
  pythonPackages = python3.withPackages (ps: with ps; [pygobject3 gst-python dbus-python pycairo]);

  fakePkExec = writeShellScriptBin "pkexec" ''
    declare -a final
    for value in "$@"; do
      final+=("$value")
    done
    exec "''${final[@]}"
  '';

  steam-run-custom =
    (steam.override {
      extraPkgs = ps: with ps; [vkbasalt] ++ extraPackages pkgs;
      extraLibraries = pkgs: with pkgs; [gnutls openldap gmp openssl libunwind sane-backends libgphoto2 openal apulse libpcap ocl-icd libxcrypt-legacy] ++ extraLibs pkgs;
      extraProfile = ''
        export PATH=${fakePkExec}/bin:$PATH
      '';
    })
    .run;

  wrapper = stdenv.mkDerivation {
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
      dpkg
    ];

    autoPatchelfIgnoreMissingDeps = [
      "libpcap.so.0.8"
      "libcapi20.so.3"
    ];

    propagatedBuildInputs = [
      # gnome deps
      atk
      cairo
      gdk-pixbuf
      libxcrypt-legacy
      glib
      gstreamer
      gst-plugins-good
      gst-plugins-ugly
      gst-plugins-base
      gst-plugins-bad
      libgphoto2
      gtk3
      libgda
      libpeas
      librsvg
      pango
      vte

      sane-backends
      ocl-icd
      alsa-lib
      pulseaudio
      pythonPackages
    ];

    unpackCmd = "dpkg -x $src source";

    preFixup = ''makeWrapperArgs+=("''${gappsWrapperArgs[@]}")'';

    installPhase = ''
      mkdir -p $out/opt
      mv opt/* $out/opt/
      mv usr $out/usr

      makeWrapper ${steam-run-custom}/bin/steam-run $out/bin/crossover \
        --add-flags "$out/opt/cxoffice/bin/crossover"
      
      runHook preFixup
      runHook postInstall
    '';

    postInstall = ''
      rmdir $out/opt/cxoffice/etc
      ln -s /etc/cxoffice/license.txt $out/opt/cxoffice
      ln -s /etc/cxoffice $out/opt/cxoffice/etc
    '';
  };

  run = writeShellScriptBin "${binName}-run" ''
    run="$1"
    if [ "$run" = "" ]; then
      echo "Usage: crossover command-to-run args..." >&2
      exit 1
    fi
    shift


    set -o allexport # Export the following env vars

    ${steam-run-custom}/bin/steam-run "$run" "$@"
  '';

  icon = stdenv.mkDerivation {
    name = "${binName}-icon";
    buildCommand = let
      iconPath = "${wrapper}/opt/cxoffice/share/icons/64x64/crossover.png";
    in ''
      mkdir -p $out/share/pixmaps
      cp ${iconPath} $out/share/pixmaps/${packageName}.png
    '';
  };

  desktopEntry = makeDesktopItem {
    name = binName;
    inherit desktopName;
    genericName = desktopName;
    exec = "${wrapper}/bin/${binName} %u";
    icon = packageName;
    categories = ["Game"];
    startupWMClass = packageName;
    startupNotify = true;
  };
in
  symlinkJoin {
    inherit wrapper;
    inherit (wrapper) pname version name;
    paths = [
      icon
      desktopEntry
      wrapper
      run
    ];
    meta = with lib; {
      description = "Run your Windows® app on MacOS, Linux, or ChromeOS";
      homepage = "https://www.codeweavers.com/crossover";
      license = licenses.unfreeRedistributable;
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      platforms = ["x86_64-linux"];
    };
    passthru = {
      inherit icon desktopEntry run wrapper;
    };
  }
