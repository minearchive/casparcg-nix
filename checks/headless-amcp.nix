{
  pkgs,
  module,
  package,
}:

pkgs.testers.runNixOSTest {
  name = "casparcg-headless-amcp";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ module ];

      services.casparcg = {
        enable = true;
        configFile = ../examples/casparcg.config;
        inherit package;
        extraEnvironment.LIBGL_ALWAYS_SOFTWARE = "1";
      };

      environment.systemPackages = [ pkgs.netcat ];

      virtualisation = {
        cores = 2;
        memorySize = 2048;
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("casparcg.service", timeout=180)
    machine.wait_for_open_port(5250, timeout=180)

    with subtest("headless environment"):
        environment = machine.succeed("systemctl show casparcg.service --property=Environment --value")
        assert "EGL_PLATFORM=surfaceless" in environment
        assert "XDG_CACHE_HOME=/var/cache/casparcg" in environment
        assert "DISPLAY=" not in environment

    with subtest("AMCP VERSION and INFO"):
        version = machine.succeed("printf 'VERSION SERVER\\r\\n' | nc -w 2 127.0.0.1 5250")
        assert "201 VERSION OK" in version, version
        assert "2.5.0" in version, version

        info = machine.succeed("printf 'INFO\\r\\n' | nc -w 2 127.0.0.1 5250")
        assert "200 INFO OK" in info, info

    with subtest("restart after failure"):
        old_pid = machine.succeed("systemctl show casparcg.service --property=MainPID --value").strip()
        machine.succeed("systemctl kill --kill-who=main --signal=KILL casparcg.service")
        machine.wait_until_succeeds("systemctl is-active --quiet casparcg.service", timeout=60)
        machine.wait_for_open_port(5250, timeout=60)
        new_pid = machine.succeed("systemctl show casparcg.service --property=MainPID --value").strip()
        assert old_pid != new_pid, (old_pid, new_pid)

    with subtest("clean SIGTERM shutdown"):
        machine.succeed("systemctl stop casparcg.service")
        machine.wait_until_succeeds("! systemctl is-active --quiet casparcg.service", timeout=60)
        machine.succeed("journalctl --unit=casparcg.service | grep 'Successfully shutdown CasparCG Server'")
  '';
}
