{ lib, ... }:

{
  # Blackmagic's userspace runtime and kernel module are unfree. Keep the
  # allowlist narrow and owned by the host configuration.
  nixpkgs.config.allowUnfreePredicate =
    package:
    builtins.elem (lib.getName package) [
      "blackmagic-desktop-video"
      "decklink"
    ];

  # The NixOS module installs the matching kernel modules and helper service.
  hardware.decklink.enable = true;

  # This only adds CasparCG service ordering and the userspace runtime path.
  services.casparcg.decklink.enable = true;
}
