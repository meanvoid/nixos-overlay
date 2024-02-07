{
  lib,
  buildFHSEnv,
  symlinkJoin,
  stdenv,
  makeDesktopItem,
  crossover-unwrapped,
  extraPkgs ? pkgs: [],
  extraLibraries ? pkgs: [],
  meta ? {},
}: let
  gnomeDeps = pkgs: with pkgs; [gnome.zenity gtksourceview gnome-desktop gnome.libgnome-keyring];
  fhsEnv = {
    # Many WINE games need 32bit
    multiArch = true;

    targetPkgs = pkgs:
      with pkgs;
        [
          crossover-unwrapped
          # This only allows to enable the toggle, vkBasalt won't work if not installed with environment.systemPackages (or nix-env)
          vkbasalt
        ]
        ++ extraPkgs pkgs;

    multiPkgs = let
      xorgDeps = pkgs:
        with pkgs.xorg; [
          libpthreadstubs
          libSM
          libX11
          libXaw
          libxcb
          libXcomposite
          libXcursor
          libXdmcp
          libXext
          libXi
          libXinerama
          libXmu
          libXrandr
          libXrender
          libXv
          libXxf86vm
        ];
      gstreamerDeps = pkgs:
        with pkgs.gst_all_1; [
          gstreamer
          gst-plugins-base
          gst-plugins-good
          gst-plugins-ugly
          gst-plugins-bad
          gst-libav
        ];
    in
      pkgs:
        with pkgs;
          [
            # https://wiki.winehq.org/Building_Wine
            alsa-lib
            cups
            dbus
            fontconfig
            freetype
            glib
            gnutls
            libglvnd
            gsm
            libgphoto2
            libjpeg_turbo
            libkrb5
            libpcap
            libpng
            libpulseaudio
            libtiff
            libunwind
            libusb1
            libv4l
            libxml2
            mpg123
            ocl-icd
            openldap
            samba4
            sane-backends
            SDL2
            udev
            vulkan-loader

            # https://www.gloriouseggroll.tv/how-to-get-out-of-wine-dependency-hell/
            alsa-plugins
            dosbox
            giflib
            gtk3
            libva
            libxslt
            ncurses
            openal

            # Steam runtime
            libgcrypt
            libgpg-error
            p11-kit
            zlib # Freetype
          ]
          ++ xorgDeps pkgs
          ++ gstreamerDeps pkgs
          ++ gnomeDeps pkgs
          ++ extraLibraries pkgs;
  };

  icon = stdenv.mkDerivation {
    name = "crossover-icon";
    buildCommand = let
      iconPath = "${crossover-unwrapped}/opt/cxoffice/share/icons/64x64/crossover.png";
    in ''
      mkdir -p $out/share/pixmaps
      cp ${iconPath} $out/share/pixmaps/crossover.png
    '';
  };

  desktopEntry = makeDesktopItem {
    name = "crossover";
    desktopName = "${crossover-unwrapped.passthru.suiteName}";
    genericName = "${crossover-unwrapped.passthru.suiteName}";
    exec = "crossover %F";
    tryExec = "crossover";
    icon = "crossover";
    categories = ["Game"];
    startupWMClass = "crossover";
    startupNotify = true;
  };
in
  symlinkJoin {
    inherit crossover-unwrapped meta;
    inherit (crossover-unwrapped) pname version name;
    paths = [
      (buildFHSEnv (fhsEnv
        // {
          name = "crossover";
          runScript = "crossover";
        }))
      (buildFHSEnv (fhsEnv
        // {
          name = "crossover-run";
          runScript = "crossover-run";
        }))
      icon
      desktopEntry
    ];
    postBuild = ''
      mkdir -p $out/share
      ln -s ${crossover-unwrapped}/opt/cxoffice/share/icons $out/share
    '';
  }
