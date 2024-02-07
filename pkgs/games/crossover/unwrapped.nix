{
  lib,
  pkgs,
  fetchurl,
  stdenv,
  writeShellScriptBin,
  glibc_multi,
  autoPatchelfHook,
  patchelf,
  wrapGAppsHook,
  gobject-introspection,
  dpkg,
  # buildInputs
  gst_all_1,
  gnome,
  python3,
  customIcon ? null,
  sourceRoot ? "",
  binPath ? "",
  libPath ? "",
  lib64Path ? "",
  sharePath ? "",
  usrPath ? "",
  suiteName ? "Crossover",
}: let
  inherit (gst_all_1) gstreamer gst-plugins-good gst-plugins-ugly gst-plugins-base gst-plugins-bad gst-libav;
  inherit (gnome) libgnome-keyring zenity;

  gnomeDeps = ps:
    with ps; [
      zenity
      gtksourceview
      gnome-desktop
      libgnome-keyring
      libgphoto2
      gtk3
      libgda
      libpeas
      librsvg
      pango
      vte
    ];
  pythonDeps = python3.withPackages (ps:
    with ps; [
      pygobject3
      gst-python
      dbus-python
      pycairo
    ]);
  neededLibs = ps:
    with ps; [
      libcap
      libxcrypt-legacy
      sane-backends
      ocl-icd
      alsa-lib
      libpulseaudio
      cabextract
      p7zip
      imagemagick
      vkbasalt-cli

      gamescope
      mangohud
      vmtouch

      # Undocumented (subprocess.Popen())
      lsb-release
      pciutils
      procps
    ];
in
  stdenv.mkDerivation rec {
    pname = "crossover-unwrapped";
    version = "23.7.1";

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

    buildInputs =
      [
        stdenv.cc.cc.lib
        pythonDeps

        gstreamer
        gst-plugins-good
        gst-plugins-ugly
        gst-plugins-base
        gst-plugins-bad
        gst-libav
      ]
      ++ gnomeDeps pkgs;

    propagatedBuildInputs = [(neededLibs pkgs)];
    ldLibraryPath = lib.strings.makeLibraryPath buildInputs;

    dontWrapGapps = true;
    unpackCmd = "dpkg -x $src source";
    installPhase = ''
      runHook preFixup
      mkdir -p $out/opt
      mv opt/* $out/opt/
      rm $out/opt/cxoffice/doc
      mv usr/share/* $out/opt/cxoffice/
      runHook postInstall
      runHook postFixup
    '';

    # postFixup = lib.optionalString stdenv.isLinux ''
    #   find $out/opt/cxoffice/lib/wine/x86_64-unix -name "*.so" | while read -r fname; do
    #     # lib needs libcapi20.so.3 but nixpkgs provides libpcap.so.1
    #     patchelf --replace-needed libcapi20.so.3 libpcap.so $fname

    #     # lib needs libpcap.so.0.8 libpcap.so.1.10.4
    #     patchelf --replace-needed libpcap.so.0.8 libpcap.so $fname
    #   done
    # '';

    autoPatchelfIgnoreMissingDeps = [
      "libpcap.so.0.8"
      "libcapi20.so.3"
    ];

    meta = with lib; {
      description = "Run your Windows® app on MacOS, Linux, or ChromeOS";
      homepage = "https://www.codeweavers.com/crossover";
      downloadPage = "https://www.codeweavers.com/account/downloads";
      license = licenses.unfree;
      mainProgram = "crossover";
      platforms = ["x86_64-linux"];
      maintainers = with maintainers; [scarletto];
    };
    passthru = {
      inherit customIcon suiteName;
      inherit binPath libPath lib64Path sharePath sourceRoot usrPath;
    };
  }