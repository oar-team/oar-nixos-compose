{
  description = "basic oar example";
  
  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/release-21.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
  };
  
  outputs = { self, nixpkgs, NUR, kapack }:
    let
      system = "x86_64-linux";

      flavours = import ./nix/flavours.nix;

      nur = import ./nix/nur.nix {
        inherit nixpkgs system NUR;
        repoOverrides = { inherit kapack; };
      };

      extraConfigurations = [
        # add nur attribute to pkgs
        { nixpkgs.overlays = [ nur.overlay ]; }
        nur.repos.kapack.modules.oar
      ];

    in {
      packages.${system} = (import ./nix/compose.nix) {
        inherit nixpkgs system extraConfigurations flavours;
      };
      defaultPackage.${system} =
        self.packages.${system}."composition::nixos-test";
    };
}
