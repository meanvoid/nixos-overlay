{
  lib,
  config,
  pkgs,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  ...
}: let
  gnrl = "535.129.03";
  vgpu = "535.129.03";
  grid = "535.129.03";
  wdys = "537.70";
  grid-version = "16.2";
  kernel-at-least-6 =
    if lib.strings.versionAtLeast config.boot.kernelPackages.kernel.version "6.0"
    then "true"
    else "false";
in let
  #!! Todo upstream the vgpu-unlock and patch
  cfg = config.hardware.nvidia.vgpu;
  compiled-driver = stdenv.mkDerivation rec {
    name = "driver-compile";
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

    nativeBuildInputs = [pkgs.coreutils pkgs.unzip pkgs.bash pkgs.zstd];

    buildPhase = ''
      mkdir -p $out
      cd $TEMPDIR

      cp -a $src/* .
      patchShebangs .

      # Copy the driver to the current directory
      cp -a $vgpuDriver NVIDIA-Linux-x86_64-${vgpu}-vgpu-kvm.run
      cp -a $generalDriver NVIDIA-Linux-x86_64-${gnrl}.run

      if ${kernel-at-least-6}; then
         pkgs.bash ./patch.sh --repack general-merge
      else
        pkgs.bash ./patch.sh --repack general-merge
      fi
      cp -a NVIDIA-Linux-x86_64-${gnrl}-merged-vgpu-kvm-patched.run $out
    '';
  };
in {
  options = {
    hardware.nvidia.vgpu = {
      enable = lib.mkEnableOption "vGPU support";
      # TODO: make source overridable and non dependent on this module
      # !!
      # submodules
      fastapi-dls = lib.mkOption {
        description = "Set up fastapi-dls host server";
        type = with lib.types;
          submodule {
            options = {
              enable = lib.mkOption {
                default = false;
                type = lib.types.bool;
                description = "Set up fastapi-dls host server";
              };
              docker-directory = lib.mkOption {
                description = "Path to your folder with docker containers";
                default = "/opt/docker";
                example = "/dockers";
                type = lib.types.str;
              };
              local_ipv4 = lib.mkOption {
                description = "Your ipv4 or local hostname, needed for the fastapi-dls server. Leave blank to autodetect using hostname";
                default = "";
                example = "192.168.1.1";
                type = lib.types.str;
              };
              timezone = lib.mkOption {
                description = "Your timezone according to this list: https://docs.diladele.com/docker/timezones.html, needs to be the same as in the VM. Leave blank to autodetect";
                default = "";
                example = "Europe/Lisbon";
                type = lib.types.str;
              };
            };
          };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (
        {
          patches ? [],
          postUnpack ? "",
          postPatch ? "",
          preFixup ? "",
          ...
        } @ attrs: {
          # Overriding https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11
          # that gets called from the option:
          # hardware.nvidia.package
          # from here: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/hardware/video/nvidia.nix
          name = "NVIDIA-Linux-x86_64-${gnrl}-merged-vgpu-kvm-patched-${config.boot.kernelPackages.kernel.version}";
          version = "${gnrl}";

          # TODO: move the derivation to other file
          # the new driver (compiled in a derivation above)
          src = "${compiled-driver}/NVIDIA-Linux-x86_64-${gnrl}-merged-vgpu-kvm-patched.run";

          ibtSupport = true;
          patches = null;

          postPatch =
            if postPatch != null
            then
              postPatch
              + ''
                # Move path for vgpuConfig.xml into /etc
                sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

                substituteInPlace sriov-manage \
                  --replace lspci ${pkgs.pciutils}/bin/lspci \
                  --replace setpci ${pkgs.pciutils}/bin/setpci
              ''
            else ''
              # Move path for vgpuConfig.xml into /etc
              sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

              substituteInPlace sriov-manage \
                --replace lspci ${pkgs.pciutils}/bin/lspci \
                --replace setpci ${pkgs.pciutils}/bin/setpci
            '';

          # HACK: Using preFixup instead of postInstall
          # nvidia-x11 builder.sh doesn't support hooks
          preFixup =
            preFixup
            + ''
              for i in libnvidia-vgpu.so.${vgpu} libnvidia-vgxcfg.so.${vgpu}; do
                install -Dm755 "$i" "$out/lib/$i"
              done
              patchelf --set-rpath ${stdenv.cc.cc.lib}/lib $out/lib/libnvidia-vgpu.so.${vgpu}
              install -Dm644 vgpuConfig.xml $out/vgpuConfig.xml

              for i in nvidia-vgpud nvidia-vgpu-mgr; do
                install -Dm755 "$i" "$bin/bin/$i"
                # stdenv.cc.cc.lib is for libstdc++.so needed by nvidia-vgpud
                patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                  --set-rpath $out/lib "$bin/bin/$i"
              done
              install -Dm755 sriov-manage $bin/bin/sriov-manage
            '';
        }
      );

      systemd.services.nvidia-vgpud = {
        description = "NVIDIA vGPU Daemon";
        wants = ["syslog.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "forking";
          ExecStart = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpud";
          ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpud";
          Environment = ["__RM_NO_VERSION_CHECK=1"]; # Avoids issue with API version incompatibility when merging host/client drivers
        };
      };

      systemd.services.nvidia-vgpu-mgr = {
        description = "NVIDIA vGPU Manager Daemon";
        wants = ["syslog.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "forking";
          KillMode = "process";
          ExecStart = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpu-mgr";
          ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpu-mgr";
          Environment = ["__RM_NO_VERSION_CHECK=1"];
        };
      };

      environment.etc."nvidia-vgpu-xxxxx/vgpuConfig.xml".source = config.hardware.nvidia.package + /vgpuConfig.xml;

      boot.kernelModules = ["nvidia-vgpu-vfio"];

      environment.systemPackages = [pkgs.mdevctl];
      services.udev.packages = [pkgs.mdevctl];
    })
    (lib.mkIf cfg.fastapi-dls.enable {
      virtualisation.oci-containers.containers = {
        fastapi-dls = {
          image = "collinwebdesigns/fastapi-dls:1.3.9";
          imageFile = pkgs.dockerTools.pullImage {
            imageName = "collinwebdesigns/fastapi-dls";
            imageDigest = "sha256:f12c60e27835f3cf2f43ea358d7c781a521f6427a3fffd1dbb1c876de3e16e70";
            sha256 = "sha256-8Sxg4ng1888vQ+o1jXx4GlIfZCej//0duxyHbePhbnA=";
          };
          volumes = [
            "${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert:/app/cert:rw"
            "dls-db:/app/database"
          ];
          # Set environment variables
          environment = {
            TZ =
              if cfg.fastapi-dls.timezone == ""
              then config.time.timeZone
              else "${cfg.fastapi-dls.timezone}";
            DLS_URL =
              if cfg.fastapi-dls.local_ipv4 == ""
              then config.networking.hostName
              else "${cfg.fastapi-dls.local_ipv4}";
            DLS_PORT = "443";
            LEASE_EXPIRE_DAYS = "90";
            DATABASE = "sqlite:////app/database/db.sqlite";
            DEBUG = "true";
          };
          # Publish the container's port to the host
          ports = ["443:443"];
          # Don't start automatically container
          autoStart = false;
        };
      };

      systemd.timers.fastapi-dls-mgr = {
        wantedBy = ["multi-user.target"];
        timerConfig = {
          OnActiveSec = "1s";
          OnUnitActiveSec = "1h";
          AccuracySec = "1s";
          Unit = "fastapi-dls-mgr.service";
        };
      };

      systemd.services.fastapi-dls-mgr = {
        # path = [openssl];
        script = ''
          WORKING_DIR=${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert
          CERT_CHANGED=false
          recreate_private () {
            rm -f $WORKING_DIR/instance.private.pem
            openssl genrsa -out $WORKING_DIR/instance.private.pem 2048
          }
          recreate_public () {
            rm -f $WORKING_DIR/instance.public.pem
            openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
          }
          recreate_certs () {
            rm -f $WORKING_DIR/webserver.key
            rm -f $WORKING_DIR/webserver.crt
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
          }
          check_recreate() {
            if [ ! -e $WORKING_DIR/instance.private.pem ]; then
              recreate_private
              recreate_public
              recreate_certs
              CERT_CHANGED=true
            fi
            if [ ! -e $WORKING_DIR/instance.public.pem ]; then
              recreate_public
              recreate_certs
              CERT_CHANGED=true
            fi
            if [ ! -e $WORKING_DIR/webserver.key ] || [ ! -e $WORKING_DIR/webserver.crt ]; then
              recreate_certs
              CERT_CHANGED=true
            fi
            if ( ! openssl x509 -checkend 864000 -noout -in $WORKING_DIR/webserver.crt); then
              recreate_certs
              CERT_CHANGED=true
            fi
          }
          if [ ! -d $WORKING_DIR ]; then
            mkdir -p $WORKING_DIR
          fi
          check_recreate
          if ( ! systemctl is-active --quiet docker-fastapi-dls.service ); then
            systemctl start podman-fastapi-dls.service
          elif $CERT_CHANGED; then
            systemctl stop podman-fastapi-dls.service
            systemctl start podman-fastapi-dls.service
          fi
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    })
  ];
}
