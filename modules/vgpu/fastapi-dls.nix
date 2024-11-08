{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib;
let
  cfg = config.services.fastapi-dls;

  user = config.users.users.dls.name;
  group = config.users.groups.dls.name;

  pkg = pkgs.callPackage ./default.nix { };

  nameToEnvVar =
    name:
    let
      parts = builtins.split "([A-Z0-9]+)" name;
      partsToEnvVar =
        parts:
        foldl' (
          key: x:
          let
            last = stringLength key - 1;
          in
          if isList x then
            key + optionalString (key != "" && substring last 1 key != "_") "_" + head x
          else if key != "" && elem (substring 0 1 x) lowerChars then # to handle e.g. [ "disable" [ "2FAR" ] "emember" ]
            substring 0 last key + optionalString (substring (last - 1) 1 key != "_") "_" + substring last 1 key + toUpper x
          else
            key + toUpper x
        ) "" parts;
    in
    if builtins.match "[A-Z0-9_]+" name != null then name else partsToEnvVar parts;

  # Due to the different naming schemes allowed for config keys,
  # we can only check for values consistently after converting them to their corresponding environment variable name.
  configEnv =
    let
      configEnv = concatMapAttrs (
        name: value:
        optionalAttrs (value != null) {
          ${nameToEnvVar name} = if isBool value then boolToString value else toString value;
        }
      ) cfg.config;
    in
    {
      DATABASE = "/var/lib/fastapi-dls";
    }
    // configEnv;

  configFile = pkgs.writeText "env" (concatStrings (mapAttrsToList (name: value: "${name}=${value}\n") configEnv));
  fastapi-dls = cfg.package.override { inherit (cfg) dbBackend; };
in
{
  options.services.fastapi-dls = with types; {
    enable = mkEnableOption (lib.mdDoc "fastapi-dls licensing server");

    dbBackend = mkOption {
      type = enum [
        "sqlite"
        "mysql"
        "postgresql"
      ];
      default = "sqlite";
      description = lib.mdDoc ''
        Which database backend vaultwarden will be using.
      '';
    };

    baseDir = mkOption {
      type = attrsOf (oneOf [
        str
        path
      ]);
      default = "/var/lib/fastapi-dls";
      example = lib.mdDoc "/opt/fastapi-dls";
      description = lib.mdDoc "Where fastapi will be";
    };

    config = mkOption {
      type = attrsOf (
        nullOr (oneOf [
          bool
          int
          str
        ])
      );
      default = {
        DEBUG = false;
        DLS_URL = "::1"; # defaults to localhost
        DLS_PORT = 443; # defaults to 443
        TOKEN_EXPIRE_DAYS = 1;
        LEASE_EXPIRE_DAYS = 90;
        LEASE_RENEWAL_PERIOD = 0.15;
        DATABASE = "sqlite:///${BASE_DIR}/app/db.sqlite"; # defautls to sqlite
      };
      description = lib.mdDoc "The env configuration";
    };

    environmentFile = mkOption {
      type = with types; nullOr path;
      default = null;
      example = "/var/lib/fastapi-dls/app/env";
      description = lib.mdDoc "Additional environment file as defined in {manpage}`systemd.exec(5)`.";
    };

    package = mkPackageOption pkg "fastapi-dls" { };
  };
  config = mkIf cfg.enable {
    users.users.dls = {
      inherit group;
      isSystemUser = true;
    };
    users.groups.dls = { };

    systemd.services.fastapi = {
      aliases = [ "fastapi-dls.service" ];
      after = [ "network.target" ];
      path = [
        pkgs.openssl
        pkg
      ];
      serviceConfig = {
        User = user;
        Group = group;

        EnvironmentFile = [ configFile ] ++ optional (cfg.environmentFile != null) cfg.environmentFile;

        ExecStart = "${fastapi-dls}/bin/fastapi-dls";

        LimitNOFILE = "1048576";

        PrivateTmp = "true";
        PrivateDevices = "true";
        ProtectHome = "true";
        ProtectSystem = "strict";

        AmbientCapabilities = "CAP_NET_BIND_SERVICE";

        StateDirectory = "fastapi-dls";
        StateDirectoryMode = "0700";

        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
  # uses attributes of the linked package
  meta.buildDocsInSandbox = false;
}
