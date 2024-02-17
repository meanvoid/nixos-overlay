{
  config,
  lib,
  pkgs,
  stdenv,
  pciutils,
  coreutils,
  openssl,
  ...
}: let
  gnrl = "535.129.03";
  vgpu = "535.129.03";
  grid = "535.129.03";
  wdys = "537.70";
  grid-version = "16.2";
  compile-driver = ./compile-driver.nix {};
  vgpu_unlock = pkgs.callPackage ./vgpu_unlock.nix {};
  cfg = config.hardware.nvidia.vgpu;
in {
  options = {
    hardware.nvidia.vgpu = {
      enable = lib.mkEnableOption "vGPU support";
      unlock.enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Unlock vGPU functionality for consumer grade GPUs";
      };
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
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production.overrideAttrs (
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

          src = "${compile-driver}/NVIDIA-Linux-x86_64-${gnrl}-merged-vgpu-kvm-patched.run";

          postPatch =
            if postPatch != null
            then
              postPatch
              + ''
                # Move path for vgpuConfig.xml into /etc
                sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

                substituteInPlace sriov-manage \
                  --replace lspci ${pciutils}/bin/lspci \
                  --replace setpci ${pciutils}/bin/setpci
              ''
            else ''
              # Move path for vgpuConfig.xml into /etc
              sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

              substituteInPlace sriov-manage \
                --replace lspci ${pciutils}/bin/lspci \
                --replace setpci ${pciutils}/bin/setpci
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
          ExecStart = "${vgpu_unlock}/bin/vgpu_unlock ${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpud";
          ExecStopPost = "${coreutils}/bin/rm -rf /var/run/nvidia-vgpud";
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
          ExecStart = "${vgpu_unlock}/bin/vgpu_unlock ${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpu-mgr";
          ExecStopPost = "${coreutils}/bin/rm -rf /var/run/nvidia-vgpu-mgr";
          Environment = ["__RM_NO_VERSION_CHECK=1"];
        };
      };

      environment.etc."nvidia-vgpu-xxxxx/vgpuConfig.xml".source = config.hardware.nvidia.package + /vgpuConfig.xml;

      boot.kernelModules = ["nvidia-vgpu-vfio"];
      boot.blacklistedKernelModules = ["nouveau"];
      # just in case we blocklist nouveau driver
      # and add workarounds
      boot.extraModprobeConfig = ''
        blacklist nouveau

        options nvidia cudahost=1 vup_sunlock=1 vup_swrlwar=1 vup_qmode=1
      '';
      programs.mdevctl.enable = true;
    })
    (lib.mkIf cfg.fastapi-dls.enable {
      virtualisation.oci-containers.containers = {
        fastapi-dls = {
          image = "collinwebdesigns/fastapi-dls";
          imageFile = pkgs.dockerTools.pullImage {
            imageName = "collinwebdesigns/fastapi-dls";
            imageDigest = "sha256:6fa90ce552c4e9ecff9502604a4fd42b3e67f52215eb6d8de03a5c3d20cd03d1";
            sha256 = "sha256-Crt5+smOuQ67pZH6g09crP9NO5h2zo/++L0rrGIVxPg=";
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
        path = [openssl];
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
