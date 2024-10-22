{
  description = "OAR usermode on Slurm Cluster";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";
    nxc.url = "gitlab:nixos-compose/nixos-compose/23.11?host=gitlab.inria.fr";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    oar-usermode.url = "github:oar-team/oar3/usermode";
    oar-usermode.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {self, nixpkgs, nxc, oar-usermode}:
    let
      system = "x86_64-linux";
    in {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system;
        overlays = [
          (self: super: {
            oar-usermode = oar-usermode.packages.${system}.oar;
          })
        ];
        setup = ./setup.toml;
        composition = ./composition.nix;
      };
      devShell.${system} = nxc.devShells.${system}.nxcShell;
    };
}

