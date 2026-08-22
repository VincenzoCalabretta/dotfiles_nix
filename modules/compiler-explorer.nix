{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.compiler-explorer;
  compiler-explorer = pkgs.callPackage ../packages/compiler-explorer.nix { };
in
{
  options.dotfiles.compiler-explorer = {
    enable = lib.mkEnableOption "the self-hosted Compiler Explorer service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 10240;
      description = "Loopback TCP port exposed by the Compiler Explorer socket.";
    };

    idleTimeoutSec = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds without an HTTP request before the activated service exits.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.sockets.compiler-explorer = {
      description = "Compiler Explorer activation socket";
      wantedBy = [ "sockets.target" ];
      listenStreams = [ "127.0.0.1:${toString cfg.port}" ];
      socketConfig = {
        NoDelay = true;
      };
    };

    systemd.services.compiler-explorer = {
      description = "Self-hosted Compiler Explorer";
      requires = [ "compiler-explorer.socket" ];
      after = [ "compiler-explorer.socket" ];
      environment = {
        HOME = "/var/lib/compiler-explorer";
        IDLE_TIMEOUT = toString cfg.idleTimeoutSec;
      };
      serviceConfig = {
        ExecStart = lib.getExe compiler-explorer;
        DynamicUser = true;
        StateDirectory = "compiler-explorer";
        CacheDirectory = "compiler-explorer";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        SystemCallArchitectures = "native";
      };
    };
  };
}
