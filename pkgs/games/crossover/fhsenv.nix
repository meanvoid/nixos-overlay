{
  lib,
  buildFHSEnv,
  stdenv,
  pkgsi686Linux,
  writeShellScript,
  crossover,
  extraPkgs ? pkgs: [],
  extraLibraries ? pkgs: [],
  extraProfile ? "",
  extraBwrapArgs ? [],
  extraArgs ? "",
  extraEnv ? {},
}: let
  commonTargetPkgs = pkgs:
    with pkgs;
      [
        nssmdns
        # Needed for operating system detection until
        # https://github.com/ValveSoftware/steam-for-linux/issues/5909 is resolved
        lsb-release
        # Errors in output without those
        pciutils
        # Games' dependencies
        xorg.xrandr
        which
        # Needed by gdialog, including in the steam-runtime
        perl
        # Open URLs
        xdg-utils
        iana-etc
        # Steam Play / Proton
        python3
        # Steam VR
        procps
        usbutils

        # It tries to execute xdg-user-dir and spams the log with command not founds
        xdg-user-dirs

        # electron based launchers need newer versions of these libraries than what runtime provides
        mesa
        sqlite
        vte
        pango
        glib
        gmp

        desktop-file-utils
        sane-backends
        ocl-icd
        libunwind
        libxcrypt-legacy
        libgphoto2
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        gst_all_1.gst-plugins-bad
        gst_all_1.gst-plugins-ugly
        pkgsi686Linux.gst_all_1.gstreamer
        pkgsi686Linux.gst_all_1.gst-plugins-base
        pkgsi686Linux.gst_all_1.gst-plugins-good
        pkgsi686Linux.gst_all_1.gst-plugins-bad
        pkgsi686Linux.gst_all_1.gst-plugins-ugly
        openal
        apulse
        fontconfig
        gnutls
        gsm
        libexif
        openldap
        pulseaudio
        xorg.libXcomposite
        xorg.libXinerama
        libxml2
        libxslt
        xorg.libXxf86vm
        xorg.libXxf86dga
        mpg123
        nss_latest
        sane-frontends
        sane-backends
        v4l-utils
      ]
      ++ extraPkgs pkgs;

  ldPath =
    lib.optionals stdenv.is64bit ["/lib64"]
    ++ ["/lib32"];

  # Zachtronics and a few other studios expect STEAM_LD_LIBRARY_PATH to be present
  exportLDPath = ''
    export LD_LIBRARY_PATH=${lib.concatStringsSep ":" ldPath}''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH
  '';

  envScript = lib.toShellVars extraEnv;
in
  buildFHSEnv rec {
    name = "crossover";

    # crossover needs 32bit
    multiArch = true;

    targetPkgs = pkgs:
      with pkgs;
        [
          crossover
          gnome.zenity
          vte
          vte-gtk4
          gtk3
          gtk4
          (python3.withPackages (p:
            with p; [
              pygobject3
              gst-python
              dbus-python
              pycairo
            ]))
        ]
        ++ commonTargetPkgs pkgs;
    multiPkgs = pkgs:
      with pkgs;
        [
          # These are required by steam with proper errors
          xorg.libXcomposite
          xorg.libXtst
          xorg.libXrandr
          xorg.libXext
          xorg.libX11
          xorg.libXfixes
          vte
          libGL
          libva
          pipewire

          # steamwebhelper
          harfbuzz
          libthai
          pango

          lsof # friends options won't display "Launch Game" without it
          file # called by steam's setup.sh

          # dependencies for mesa drivers, needed inside pressure-vessel
          mesa.llvmPackages.llvm.lib
          vulkan-loader
          expat
          wayland
          xorg.libxcb
          xorg.libXdamage
          xorg.libxshmfence
          xorg.libXxf86vm
          libelf
          (lib.getLib elfutils)

          # Without these it silently fails
          xorg.libXinerama
          xorg.libXcursor
          xorg.libXrender
          xorg.libXScrnSaver
          xorg.libXi
          xorg.libSM
          xorg.libICE
          gnome2.GConf
          curlWithGnuTls
          nspr
          nss
          cups
          libcap
          SDL2
          libusb1
          dbus-glib
          gsettings-desktop-schemas
          ffmpeg
          libudev0-shim

          # Verified games requirements
          fontconfig
          freetype
          xorg.libXt
          xorg.libXmu
          libogg
          libvorbis
          SDL
          SDL2_image
          glew110
          libdrm
          libidn
          tbb
          zlib

          # SteamVR
          udev
          dbus

          # Other things from runtime
          glib
          gtk2
          bzip2
          flac
          freeglut
          libjpeg
          libpng
          libpng12
          libsamplerate
          libmikmod
          libtheora
          libtiff
          pixman
          speex
          SDL_image
          SDL_ttf
          SDL_mixer
          SDL2_ttf
          SDL2_mixer
          libappindicator-gtk2
          libdbusmenu-gtk2
          libindicator-gtk2
          libcaca
          libcanberra
          libgcrypt
          libunwind
          libvpx
          librsvg
          xorg.libXft
          libvdpau
          at-spi2-atk
          at-spi2-core # CrossCode
          gst_all_1.gstreamer
          gst_all_1.gst-plugins-ugly
          gst_all_1.gst-plugins-base
          json-glib # paradox launcher (Stellaris)
          libdrm
          libxkbcommon # paradox launcher
          libvorbis # Dead Cells
          libxcrypt # Alien Isolation, XCOM 2, Company of Heroes 2
          mono
          ncurses # Crusader Kings III
          openssl
          xorg.xkeyboardconfig
          xorg.libpciaccess
          xorg.libXScrnSaver # Dead Cells
          icu # dotnet runtime, e.g. Stardew Valley

          # screeps dependencies
          gtk3
          zlib
          atk
          cairo
          freetype
          gdk-pixbuf
          fontconfig

          # Prison Architect
          libGLU
          libuuid
          libbsd
          alsa-lib

          # Loop Hero
          # FIXME: Also requires openssl_1_1, which is EOL. Either find an alternative solution, or remove these dependencies (if not needed by other games)
          libidn2
          libpsl
          nghttp2.lib
          rtmpdump
          attr
        ]
        ++ commonTargetPkgs pkgs
        ++ extraLibraries pkgs;
    extraInstallCommands = ''
      mkdir -p $out/share
      ln -sf ${crossover}/opt/cxoffice/share/applications $out/share
      ln -sf ${crossover}/opt/share/icons $out/share
    '';

    runScript = writeShellScript "crossover-run" ''
      run="$1"
      if [ "$run" = "" ]; then
        echo "Usage: crossover command-to-run args..." >&2
        exit 1
      fi
      shift

      ${exportLDPath}

      set -o allexport # Export the following env vars
      ${envScript}
      exec -- "$run" "$@"
    '';

    meta = crossover.meta;
  }
