{
  nixpkgs,
  pkgs,
  module,
}:

let
  evaluate =
    settings:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        module
        {
          services.casparcg = settings;
          system.stateVersion = "26.05";
        }
      ];
    };

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

  missingConfig = (evaluate { enable = true; }).config;
  configFileAssertion = pkgs.lib.findFirst (
    assertion: pkgs.lib.hasInfix "services.casparcg.configFile" assertion.message
  ) null missingConfig.assertions;
in
assert defaultConfig.hardware.graphics.enable;
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
assert defaultConfig.users.users.casparcg.isSystemUser;
assert defaultConfig.users.users.casparcg.group == "casparcg";
assert builtins.elem "video" defaultConfig.users.users.casparcg.extraGroups;
assert builtins.elem "render" defaultConfig.users.users.casparcg.extraGroups;
assert exposedConfig.networking.firewall.allowedTCPPorts == [ 5250 ];
assert !(exposedConfig.systemd.services.casparcg.serviceConfig ? UnsetEnvironment);
assert configFileAssertion != null;
assert !configFileAssertion.assertion;
pkgs.runCommand "casparcg-module-eval" { } ''
  touch "$out"
''
