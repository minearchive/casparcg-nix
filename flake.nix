{
  description = "Reproducible Nix packaging and NixOS integration for CasparCG Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      overlay = final: _previous: {
        casparcg-server-minimal = final.callPackage ./nix/casparcg {
          withHtml = false;
        };
      };
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      casparcgModule = { ... }: {
        imports = [ ./nix/modules/casparcg.nix ];
        nixpkgs.overlays = [ overlay ];
      };
      formatterFor =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.writeShellApplication {
          name = "casparcg-nix-fmt";
          text = ''
            exec ${pkgs.nixfmt-tree}/bin/treefmt --tree-root-file flake.nix "$@"
          '';
        };
    in
    {
      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          formatting = pkgs.runCommand "casparcg-nix-formatting" { } ''
            ${pkgs.nixfmt}/bin/nixfmt --check \
              ${./flake.nix} \
              ${./nix/casparcg/default.nix} \
              ${./nix/modules/casparcg.nix} \
              ${./examples/host.nix}
            touch "$out"
          '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              cmake
              deadnix
              git
              ninja
              nixfmt-tree
              pkg-config
              statix
            ];
          };
        }
      );

      nixosModules = {
        casparcg = casparcgModule;
        default = casparcgModule;
      };

      overlays.default = overlay;

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit (pkgs) casparcg-server-minimal;
          default = pkgs.casparcg-server-minimal;
        }
      );

      formatter = forAllSystems formatterFor;
    };
}
