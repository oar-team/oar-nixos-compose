{
  description = "OAR - basic setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nxc, NUR, kapack}:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      nur = nxc.lib.nur {
        inherit nixpkgs system NUR;
        repoOverrides = { inherit kapack; };
   };
  
      extraConfigurations = [
        # add nur attribute to pkgs
        { nixpkgs.overlays = [ nur.overlay ]; }
        nur.repos.kapack.modules.oar
        ];
  
      composition = import ./composition.nix;

    in {
      packages.${system} =
        nxc.lib.compose { inherit nixpkgs system composition extraConfigurations; };

      defaultPackage.${system} =
        self.packages.${system}."composition::nixos-test";
   
      devShell.${system} = pkgs.mkShell { buildInputs = [ nxc.defaultPackage.${system} ];};
    };
}
