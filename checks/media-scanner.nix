{
  pkgs,
  module,
  package,
  scannerPackage,
}:

pkgs.testers.runNixOSTest {
  name = "casparcg-media-scanner";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ module ];

      services.casparcg = {
        enable = true;
        configFile = ../examples/casparcg.config;
        inherit package;
        extraEnvironment.LIBGL_ALWAYS_SOFTWARE = "1";
        mediaScanner = {
          enable = true;
          package = scannerPackage;
        };
      };

      environment.systemPackages = with pkgs; [
        curl
        ffmpeg_7
        iproute2
        netcat
      ];

      virtualisation = {
        cores = 2;
        memorySize = 3072;
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("casparcg.service", timeout=180)
    machine.wait_for_open_port(5250, timeout=180)
    machine.wait_for_unit("casparcg-media-scanner.service", timeout=180)
    machine.wait_for_open_port(8000, timeout=180)

    with subtest("local HTTP endpoint"):
        machine.succeed("ss -H -ltn | grep -E '127\\.0\\.0\\.1:8000[[:space:]]'")
        media = machine.succeed("curl -fsS http://127.0.0.1:8000/media")
        assert media.strip() == "[]", media

    with subtest("shared media directory and metadata"):
        machine.succeed(
            "ffmpeg -hide_banner -loglevel error "
            "-f lavfi -i testsrc=size=64x64:rate=25 -t 1 "
            "-c:v mpeg4 -pix_fmt yuv420p -y /srv/casparcg/media/sample.mp4"
        )
        machine.succeed("chown casparcg:casparcg /srv/casparcg/media/sample.mp4")
        machine.wait_until_succeeds(
            "curl -fsS http://127.0.0.1:8000/media | grep -q '\"name\":\"SAMPLE\"'",
            timeout=120,
        )

        info = machine.succeed("curl -fsS http://127.0.0.1:8000/media/info/SAMPLE")
        assert '"name":"SAMPLE"' in info, info
        assert '"type":"video"' in info, info

        machine.succeed(
            "curl -fsS http://127.0.0.1:8000/media/thumbnail/SAMPLE -o /tmp/sample.png"
        )
        magic = machine.succeed("od -An -tx1 -N8 /tmp/sample.png | tr -d ' \\n'").strip()
        assert magic == "89504e470d0a1a0a", magic

    with subtest("CasparCG media commands use the scanner"):
        cls = machine.succeed("printf 'CLS\\r\\n' | nc -w 5 127.0.0.1 5250")
        assert "200 CLS OK" in cls, cls
        assert '"SAMPLE"' in cls, cls

        cinf = machine.succeed("printf 'CINF SAMPLE\\r\\n' | nc -w 5 127.0.0.1 5250")
        assert "201 CINF OK" in cinf, cinf
        assert "MOVIE" in cinf, cinf

    with subtest("scanner lifecycle is independent"):
        machine.succeed("systemctl stop casparcg-media-scanner.service")
        machine.fail("systemctl is-active --quiet casparcg-media-scanner.service")
        machine.succeed("systemctl is-active --quiet casparcg.service")

        version = machine.succeed("printf 'VERSION SERVER\\r\\n' | nc -w 5 127.0.0.1 5250")
        assert "201 VERSION OK" in version, version
  '';
}
