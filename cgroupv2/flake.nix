{
  description = "OAR - basic setup";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
    nxc.url = "gitlab:nixos-compose/nixos-compose/23.05?host=gitlab.inria.fr";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack/dynres";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nxc, NUR, kapack}:
    let
      system = "x86_64-linux";
      
    in {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system NUR;
        repoOverrides = { inherit kapack; };
        composition = ./composition.nix;
        setup = ./setup.toml;
      };
      
      devShell.${system} = nxc.devShells.${system}.nxcShell;
    };
}

