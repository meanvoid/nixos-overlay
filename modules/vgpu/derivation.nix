{
  lib,
  pkgs,
  config,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  coreutils,
  unzip,
  bash,
  zstd,
}:
with lib; let
  gnrl = "535.129.03";
  vgpu = "535.129.03";
  grid = "535.129.03";
  wdys = "537.70";
  grid-version = "16.2";
  kernel-at-least-6 = "true";
in
  stdenv.mkDerivation rec {
    pname = "compiled-driver";
    version = "e52889";
    system = "x86_64-linux";

    src = fetchFromGitHub {
      owner = "VGPU-Community-Drivers";
      repo = "vGPU-Unlock-patcher";
      rev = "e5288921f79b28590caec6b5249bcac92b6641cb";
      sha256 = "sha256-dt6aWul7vZ7fiNgLDsyF9+MXDjIDxGagQ0HzU2NOb8U=";
      fetchSubmodules = true;
    };
    generalDriver = fetchurl {
      url = "https://download.nvidia.com/XFree86/Linux-x86_64/${gnrl}/NVIDIA-Linux-x86_64-${gnrl}.run";
      sha256 = "sha256-5tylYmomCMa7KgRs/LfBrzOLnpYafdkKwJu4oSb/AC4=";
    };
    vgpuDriver = stdenv.fetchurlBoot {
      url = "https://www.tenjin-dk.com/archive/nvidia/NVIDIA-Linux-x86_64-535.129.03-vgpu-kvm.run";
      sha256 = "sha256-KlOUDaFsfIvwAeXaD1OYMZL00J7ITKtxP7tCSsEd90M=";
    };

    nativeBuildInputs = [coreutils unzip bash zstd];

    buildPhase = ''
      mkdir -p $out
      cd $TEMPDIR

      cp -a $src/* .
      patchShebangs .

      # Copy the driver to the current directory
      cp -a $vgpuDriver NVIDIA-Linux-x86_64-${vgpu}-vgpu-kvm.run
      cp -a $generalDriver NVIDIA-Linux-x86_64-${gnrl}.run

      if ${kernel-at-least-6}; then
         bash ./patch.sh --repack general-merge
      else
        bash ./patch.sh --repack general-merge
      fi
      cp -a NVIDIA-Linux-x86_64-${gnrl}-merged-vgpu-kvm-patched.run $out
    '';
  }
