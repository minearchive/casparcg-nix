{
  pkgs,
  module,
  package,
}:

pkgs.testers.runNixOSTest {
  name = "casparcg-headless-html";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ module ];

      services.casparcg = {
        enable = true;
        configFile = ./fixtures/casparcg-html.config;
        inherit package;
        extraEnvironment.LIBGL_ALWAYS_SOFTWARE = "1";
      };

      environment = {
        etc."casparcg/smoke.html".source = ./fixtures/smoke.html;
        systemPackages = [ pkgs.netcat ];
      };

      virtualisation = {
        cores = 2;
        memorySize = 3072;
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("casparcg.service", timeout=240)
    machine.wait_for_open_port(5250, timeout=240)

    with subtest("CEF initializes with packaged resources"):
        machine.wait_until_succeeds(
            "journalctl --unit=casparcg.service | grep 'Initialized html module'",
            timeout=120,
        )
        journal = machine.succeed("journalctl --unit=casparcg.service")
        assert "Failed to initialize CEF" not in journal
        assert "Invalid file descriptor to ICU data" not in journal
        assert "Failed to load resource" not in journal

    with subtest("HTML producer loads and renders"):
        play = machine.succeed(
            "printf 'PLAY 1-1 [HTML] file:///etc/casparcg/smoke.html\\r\\n' | nc -w 5 127.0.0.1 5250"
        )
        assert "202 PLAY OK" in play, play

        machine.wait_until_succeeds(
            "journalctl --unit=casparcg.service | grep 'casparcg-cef-smoke-ready'",
            timeout=60,
        )
        info = machine.succeed("printf 'INFO 1-1\\r\\n' | nc -w 5 127.0.0.1 5250")
        assert "<producer>html</producer>" in info, info
        assert "<path>file:///etc/casparcg/smoke.html</path>" in info, info
        machine.succeed("test -d /var/cache/casparcg/cef")

        stop = machine.succeed("printf 'STOP 1-1\\r\\n' | nc -w 5 127.0.0.1 5250")
        assert "202 STOP OK" in stop, stop

    with subtest("CEF subprocesses exit with the service"):
        machine.succeed("systemctl stop casparcg.service")
        machine.fail("systemctl is-active --quiet casparcg.service")
        machine.succeed("! pgrep -f '[t]ype=renderer'")
        machine.succeed("journalctl --unit=casparcg.service | grep 'Successfully shutdown CasparCG Server'")
  '';
}
