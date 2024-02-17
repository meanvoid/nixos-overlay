{
  lib,
  pkgs,
  config,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  unzip,
  zstd,
  p7zip,
  bash,
  coreutils,
  perl,
  nukeReferences,
  which,
  libarchive,
  ...
}:
with lib; let
  gnrl = "535.129.03";
  vgpu = "535.129.03";
  grid = "535.129.03";
  wdys = "537.70";
  grid-version = "16.2";

  libPathFor = pkgs:
    lib.makeLibraryPath (with pkgs; [
      libdrm
      xorg.libXext
      xorg.libX11
      xorg.libXv
      xorg.libXrandr
      xorg.libxcb
      zlib
      stdenv.cc.cc
      wayland
      mesa
      libGL
      openssl
      dbus # for nvidia-powerd
    ]);
in
  stdenv.mkDerivation rec {
    name = "compile-driver";
    src =
      if stdenv.hostPlatform.system == "x86_64-linux"
      then
        fetchFromGitHub
        {
          owner = "VGPU-Community-Drivers";
          repo = "vGPU-Unlock-patcher";
          rev = "e5288921f79b28590caec6b5249bcac92b6641cb";
          hash = "sha256-dt6aWul7vZ7fiNgLDsyF9+MXDjIDxGagQ0HzU2NOb8U=";
          fetchSubmodules = true;
        }
      else throw "vGPU does not support platform ${stdenv.hostPlatform.system}";

    generalDriver = fetchurl {
      url = "https://download.nvidia.com/XFree86/Linux-x86_64/${gnrl}/NVIDIA-Linux-x86_64-${gnrl}.run";
      sha256 = "sha256-5tylYmomCMa7KgRs/LfBrzOLnpYafdkKwJu4oSb/AC4=";
    };

    # TODO: make this overridable
    vgpuDriver = stdenv.fetchurlBoot {
      url = "https://www.tenjin-dk.com/archive/nvidia/${grid}/Host_Driver/NVIDIA-Linux-x86_64-${vgpu}-vgpu-kvm.run";
      sha256 = "sha256-KlOUDaFsfIvwAeXaD1OYMZL00J7ITKtxP7tCSsEd90M=";
    };

    # TODO: make custom unpacking to fix the issue with makeself.sh not being able to find nvidia-installer
    dontStrip = true;
    dontPatchELF = true;

    nativeBuildInputs = [
      unzip
      zstd
      p7zip
      bash
      coreutils
      perl
      nukeReferences
      which
      libarchive
    ];

    buildPhase = ''
      runHook preBuild
      cd $(mktemp -d) # temporary

      echo "Copying from source to $(pwd)"

      cp -ar $src/* .
      chmod -R u+w .
      cp -ar $generalDriver NVIDIA-Linux-x86_64-${gnrl}.run
      cp -ar $vgpuDriver NVIDIA-Linux-x86_64-${vgpu}-vgpu-kvm.run

      patchShebangs .

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out

      bash patch.sh \
        --repack \
        --force-nvidia-gpl-I-know-it-is-wrong \
        --enable-nvidia-gpl-for-experimenting \
        general-merge

      cp -ar * $out
      runHook postInstall
    '';

    meta = with lib; {
      homepage = "";
      description = "vGPU driver and kernel module for NVIDIA vGPU licensed cards merged with Nvidia driver";
      license = licenses.unfree;
      platforms = ["x86_64-linux"];
      maintainers = with maintainers; [ashuramaruzxc];
      priority = 4; # resolves collision with xorg-server's "lib/xorg/modules/extensions/libglx.so"
    };
  }
