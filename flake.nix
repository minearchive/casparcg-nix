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
        casparcg-cef-142 = final.callPackage ./nix/casparcg/cef.nix { };
        casparcg-server = final.callPackage ./nix/casparcg {
          cef = final.casparcg-cef-142;
          withHtml = true;
        };
        casparcg-server-minimal = final.callPackage ./nix/casparcg {
          withHtml = false;
        };
        media-scanner = final.callPackage ./nix/media-scanner { };
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
          full-build = pkgs.casparcg-server;

          headless-html = import ./checks/headless-html.nix {
            inherit pkgs;
            module = ./nix/modules/casparcg.nix;
            package = pkgs.casparcg-server;
          };

          headless-amcp = import ./checks/headless-amcp.nix {
            inherit pkgs;
            module = ./nix/modules/casparcg.nix;
            package = pkgs.casparcg-server-minimal;
          };

          minimal-build = pkgs.casparcg-server-minimal;

          media-scanner-build = pkgs.media-scanner;

          media-scanner = import ./checks/media-scanner.nix {
            inherit pkgs;
            module = ./nix/modules/casparcg.nix;
            package = pkgs.casparcg-server-minimal;
            scannerPackage = pkgs.media-scanner;
          };

          module-eval = import ./checks/module-eval.nix {
            inherit nixpkgs pkgs;
            module = casparcgModule;
          };

          formatting = pkgs.runCommand "casparcg-nix-formatting" { } ''
            ${pkgs.nixfmt}/bin/nixfmt --check \
              ${./flake.nix} \
              ${./nix/casparcg/default.nix} \
              ${./nix/casparcg/cef.nix} \
              ${./nix/media-scanner/default.nix} \
              ${./nix/modules/casparcg.nix} \
              ${./examples/host.nix} \
              ${./checks/module-eval.nix} \
              ${./checks/headless-amcp.nix} \
              ${./checks/headless-html.nix} \
              ${./checks/media-scanner.nix}
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
          inherit (pkgs) casparcg-server casparcg-server-minimal media-scanner;
          default = pkgs.casparcg-server;
        }
      );

      formatter = forAllSystems formatterFor;
    };
}
