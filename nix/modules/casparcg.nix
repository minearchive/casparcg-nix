{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.casparcg;
  configPath = "/etc/casparcg/casparcg.config";
  managedDirectories = [
    cfg.mediaDir
    cfg.templateDir
    cfg.dataDir
    cfg.logDir
    cfg.cacheDir
  ];
in
{
  options.services.casparcg = {
    enable = lib.mkEnableOption "CasparCG Server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.casparcg-server;
      defaultText = lib.literalExpression "pkgs.casparcg-server";
      description = "CasparCG Server package to run.";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./casparcg.config";
      description = ''
        CasparCG XML configuration file. This is the sole configuration
        authority; paths and ports in this file must match the corresponding
        module options.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "casparcg";
      description = "User account under which CasparCG runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "casparcg";
      description = "Group under which CasparCG runs.";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/casparcg/media";
      description = "Writable media directory referenced by the XML configuration.";
    };

    templateDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/casparcg/template";
      description = "Writable template directory referenced by the XML configuration.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/casparcg/data";
      description = "Working and persistent data directory.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/casparcg";
      description = "Directory used by CasparCG file logging.";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/cache/casparcg";
      description = "Runtime cache directory, including the CEF cache.";
    };

    amcpPort = lib.mkOption {
      type = lib.types.port;
      default = 5250;
      description = "AMCP port used for firewall and operational metadata.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the AMCP port on all firewall interfaces.";
    };

    headless = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use surfaceless EGL and remove DISPLAY from the service environment.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        LIBGL_ALWAYS_SOFTWARE = "1";
      };
      description = "Additional environment variables for the service.";
    };

    restartPolicy = lib.mkOption {
      type = lib.types.enum [
        "no"
        "on-success"
        "on-failure"
        "on-abnormal"
        "on-abort"
        "on-watchdog"
        "always"
      ];
      default = "on-failure";
      description = "systemd restart policy for CasparCG.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.configFile != null;
        message = "services.casparcg.configFile must be set when CasparCG is enabled.";
      }
      {
        assertion = builtins.all (directory: lib.hasPrefix "/" directory) managedDirectories;
        message = "All services.casparcg directory options must be absolute paths.";
      }
    ];

    hardware.graphics.enable = lib.mkDefault true;

    environment.etc = lib.mkIf (cfg.configFile != null) {
      "casparcg/casparcg.config".source = cfg.configFile;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.amcpPort ];

    users.groups = lib.mkIf (cfg.group == "casparcg") {
      casparcg = { };
    };

    users.users = lib.mkIf (cfg.user == "casparcg") {
      casparcg = {
        isSystemUser = true;
        inherit (cfg) group;
        extraGroups = [
          "render"
          "video"
        ];
      };
    };

    systemd.tmpfiles.rules = map (
      directory: "d ${directory} 0750 ${cfg.user} ${cfg.group} -"
    ) managedDirectories;

    systemd.services.casparcg = {
      description = "CasparCG Server";
      documentation = [ "https://github.com/CasparCG/server" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = {
        XDG_CACHE_HOME = cfg.cacheDir;
      }
      // lib.optionalAttrs cfg.headless {
        EGL_PLATFORM = "surfaceless";
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package} ${lib.escapeShellArg configPath}";
        User = cfg.user;
        Group = cfg.group;
        SupplementaryGroups = [
          "render"
          "video"
        ];
        WorkingDirectory = cfg.dataDir;

        StateDirectory = "casparcg";
        StateDirectoryMode = "0750";
        CacheDirectory = "casparcg";
        CacheDirectoryMode = "0750";
        LogsDirectory = "casparcg";
        LogsDirectoryMode = "0750";
        RuntimeDirectory = "casparcg";
        RuntimeDirectoryMode = "0750";

        Restart = cfg.restartPolicy;
        RestartSec = "2s";
        TimeoutStopSec = "30s";
        KillSignal = "SIGTERM";
      }
      // lib.optionalAttrs cfg.headless {
        UnsetEnvironment = [ "DISPLAY" ];
      };
    };
  };
}
