{
  description = "OAR - from master";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git?ref=26.05";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    kapack.url = "git+https://gricad-gitlab.univ-grenoble-alpes.fr/kairns/kapack.git?ref=master";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { nxc, nixpkgs, kapack, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
    in {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system;
        composition = ./composition.nix;
        setup = ./setup.toml;
        # Add all kapack modules
        extraConfigurations = [
          kapack.nixosModules.oar
        ];
        overlays = [
          (_: _: kapack.packages.${system})
          (final: _: {
            oar = final.callPackage "${kapack}/pkgs/oar-master" { };
          })
        ];
      };
      formatter.${system} = pkgs.writeShellScriptBin "formatter" ''
        set -eoux pipefail
        shopt -s globstar
        ${lib.getExe pkgs.deno} fmt README.md
        ${lib.getExe pkgs.nixpkgs-fmt} .
        ${lib.getExe pkgs.just} --fmt --unstable
      '';

      devShell.${system} = pkgs.mkShell {
        packages = with pkgs; [
          nushell
          yq-go
          qemu_kvm
          vde2
          tmux
          nxc.defaultPackage.${system}
        ];
      };
    };
}
