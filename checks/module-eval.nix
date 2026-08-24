{
  nixpkgs,
  pkgs,
  module,
}:

let
  evaluateWith =
    settings: extraModules:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        module
        {
          services.casparcg = settings;
          system.stateVersion = "26.05";
        }
      ]
      ++ extraModules;
    };
  evaluate = settings: evaluateWith settings [ ];

  defaultConfig =
    (evaluate {
      enable = true;
      configFile = ../examples/casparcg.config;
    }).config;

  exposedConfig =
    (evaluate {
      enable = true;
      configFile = ../examples/casparcg.config;
      headless = false;
      openFirewall = true;
    }).config;

  scannerConfig =
    (evaluate {
      enable = true;
      configFile = ../examples/casparcg.config;
      mediaScanner = {
        enable = true;
        extraArgs = [
          "--logger.level"
          "debug"
        ];
      };
    }).config;

  decklinkConfig =
    (evaluateWith {
      enable = true;
      configFile = ../examples/casparcg.config;
    } [ ../examples/decklink.nix ]).config;

  invalidDecklinkConfig =
    (evaluate {
      enable = true;
      configFile = ../examples/casparcg.config;
      decklink.enable = true;
    }).config;

  missingConfig = (evaluate { enable = true; }).config;
  configFileAssertion = pkgs.lib.findFirst (
    assertion: pkgs.lib.hasInfix "services.casparcg.configFile" assertion.message
  ) null missingConfig.assertions;
  decklinkAssertion = pkgs.lib.findFirst (
    assertion: pkgs.lib.hasInfix "hardware.decklink.enable" assertion.message
  ) null invalidDecklinkConfig.assertions;
in
assert defaultConfig.hardware.graphics.enable;
assert defaultConfig.services.casparcg.package.pname == "casparcg-server";
assert
  defaultConfig.environment.etc."casparcg/casparcg.config".source == ../examples/casparcg.config;
assert defaultConfig.networking.firewall.allowedTCPPorts == [ ];
assert pkgs.lib.hasSuffix "/etc/casparcg/casparcg.config"
  defaultConfig.systemd.services.casparcg.serviceConfig.ExecStart;
assert defaultConfig.systemd.services.casparcg.environment.EGL_PLATFORM == "surfaceless";
assert defaultConfig.systemd.services.casparcg.environment.XDG_CACHE_HOME == "/var/cache/casparcg";
assert defaultConfig.systemd.services.casparcg.serviceConfig.UnsetEnvironment == [ "DISPLAY" ];
assert defaultConfig.systemd.services.casparcg.serviceConfig.Restart == "on-failure";
assert defaultConfig.systemd.services.casparcg.serviceConfig.KillSignal == "SIGTERM";
assert !defaultConfig.services.casparcg.decklink.enable;
assert !(defaultConfig.systemd.services.casparcg.environment ? LD_LIBRARY_PATH);
assert !(builtins.hasAttr "casparcg-media-scanner" defaultConfig.systemd.services);
assert defaultConfig.users.users.casparcg.isSystemUser;
assert defaultConfig.users.users.casparcg.group == "casparcg";
assert builtins.elem "video" defaultConfig.users.users.casparcg.extraGroups;
assert builtins.elem "render" defaultConfig.users.users.casparcg.extraGroups;
assert exposedConfig.networking.firewall.allowedTCPPorts == [ 5250 ];
assert !(exposedConfig.systemd.services.casparcg.serviceConfig ? UnsetEnvironment);
assert scannerConfig.services.casparcg.mediaScanner.package.pname == "casparcg-media-scanner";
assert scannerConfig.networking.firewall.allowedTCPPorts == [ ];
assert builtins.elem "casparcg.service"
  scannerConfig.systemd.services."casparcg-media-scanner".after;
assert builtins.elem "casparcg.service"
  scannerConfig.systemd.services."casparcg-media-scanner".wants;
assert
  !(builtins.elem "casparcg.service"
    scannerConfig.systemd.services."casparcg-media-scanner".requires
  );
assert
  !(builtins.elem "casparcg.service" scannerConfig.systemd.services."casparcg-media-scanner".partOf);
assert scannerConfig.systemd.services."casparcg-media-scanner".environment.NODE_ENV == "production";
assert
  scannerConfig.systemd.services."casparcg-media-scanner".serviceConfig.StateDirectory
  == "casparcg-media-scanner";
assert pkgs.lib.hasInfix "--caspar.config /etc/casparcg/casparcg.config"
  scannerConfig.systemd.services."casparcg-media-scanner".serviceConfig.ExecStart;
assert pkgs.lib.hasInfix "--http.host 127.0.0.1 --http.port 8000"
  scannerConfig.systemd.services."casparcg-media-scanner".serviceConfig.ExecStart;
assert pkgs.lib.hasInfix "--logger.level debug"
  scannerConfig.systemd.services."casparcg-media-scanner".serviceConfig.ExecStart;
assert decklinkConfig.hardware.decklink.enable;
assert builtins.elem "DesktopVideoHelper.service" decklinkConfig.systemd.services.casparcg.after;
assert builtins.elem "DesktopVideoHelper.service" decklinkConfig.systemd.services.casparcg.wants;
assert pkgs.lib.hasInfix "blackmagic-desktop-video"
  decklinkConfig.systemd.services.casparcg.environment.LD_LIBRARY_PATH;
assert configFileAssertion != null;
assert !configFileAssertion.assertion;
assert decklinkAssertion != null;
assert !decklinkAssertion.assertion;
pkgs.runCommand "casparcg-module-eval" { } ''
  touch "$out"
''
