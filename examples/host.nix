_:

{
  services.casparcg = {
    enable = true;
    configFile = ./casparcg.config;
  };

  # Keep AMCP private by default. A same-host controller connects to
  # 127.0.0.1:5250 without opening the firewall.
  networking.firewall.enable = true;

  system.stateVersion = "26.05";
}
