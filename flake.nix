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
      pkgsFor = system: import nixpkgs { inherit system; };
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
            ${pkgs.nixfmt}/bin/nixfmt --check ${./flake.nix}
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

      formatter = forAllSystems formatterFor;
    };
}
