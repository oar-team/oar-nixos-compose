{
  description = "OAR - Evolve ";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.11";
    nxc.url = "gitlab:nixos-compose/nixos-compose/24.11?host=gitlab.inria.fr";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs_25_05.url = "github:NixOS/nixpkgs/25.05";
  };

  outputs = { self, nixpkgs, nxc, NUR, kapack, nixpkgs_25_05}:
    let
      system = "x86_64-linux";
      
    in {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system NUR;
        repoOverrides = { inherit kapack; };
        composition = ./composition.nix;
        setup = ./setup.toml;

        overlays = [
           (self: super: {
              hwloc = nixpkgs_25_05.legacyPackages.${system}.hwloc;
           })
        ];
        
      };
      
      devShell.${system} = nxc.devShells.${system}.nxcShell;
    };
}

