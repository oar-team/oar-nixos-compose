{
  description = "OAR - from master";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nxc.url = "gitlab:nixos-compose/nixos-compose/24.11?host=gitlab.inria.fr";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-master.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, nxc, NUR, kapack, nixpkgs-master}:
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
              hwloc = nixpkgs-master.legacyPackages.${system}.hwloc;
           })
        ];
        
      };
      
      devShell.${system} = nxc.devShells.${system}.nxcShell;
    };
}

