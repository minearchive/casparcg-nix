{
  description = "Same-host CasparCG and casperctl deployment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    casparcg-nix = {
      url = "github:OWNER/casparcg-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    casperctl = {
      url = "github:OWNER/casperctl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      casparcg-nix,
      casperctl,
      ...
    }:
    {
      nixosConfigurations.playout = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          casparcg-nix.nixosModules.casparcg
          casperctl.nixosModules.default
          {
            services.casparcg = {
              enable = true;
              configFile = ./casparcg.config;
            };

            services.casperctl.enable = true;

            # casperctl connects to AMCP on 127.0.0.1:5250. Do not expose
            # the unauthenticated AMCP listener through the host firewall.
            services.casparcg.openFirewall = false;
          }
        ];
      };
    };
}
