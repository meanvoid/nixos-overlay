{
  steam,
  symlinkJoin,
  writeShellScriptBin,
  stdenv,
  makeDesktopItem,
  unwrapped ? null,
  binName ? "",
  packageName ? "",
  desktopName ? "",
  meta ? {},
  extraPackages ? pkgs: [],
  extraLibs ? pkgs: [],
}: let
  fakePkExec = writeShellScriptBin "pkexec" ''
    declare -a final
    for value in "$@"; do
      final+=("$value")
    done
    exec "''${final[@]}"
  '';
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
  # TODO: custom FHS env instead of using steam-run
  steam-run-custom =
    (steam.override {
      extraPkgs = pkgs:
        with pkgs;
          [
            vkbasalt
          ]
          ++ extraPackages pkgs;
      extraLibraries = pkgs:
        with pkgs;
          [
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
          ++ extraLibs pkgs;
      extraProfile = ''
        export PATH=${fakePkExec}/bin:$PATH
      '';
    })
    .run;

  wrapper = writeShellScriptBin binName ''
    ${steam-run-custom}/bin/steam-run ${unwrapped}/opt/cxoffice/bin/${binName} "$@"
  '';

  crossover-run = writeShellScriptBin "${binName}-run" ''
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
      iconPath =
        if unwrapped.passthru.customIcon != null
        then unwrapped.passthru.customIcon
        else "${unwrapped}/opt/cxoffice/share/icons/64x64/crossover.png";
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
    inherit unwrapped meta;
    inherit (unwrapped) pname version name;
    paths = [icon desktopEntry wrapper crossover-run];

    passthru = {
      inherit icon desktopEntry wrapper crossover-run;
    };
  }
