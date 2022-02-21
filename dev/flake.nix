{
  description = "nixos-compose - composition to infrastructure";

  inputs.NUR.url = "github:nix-community/NUR";
  inputs.kapack.url = "path:/home/auguste/dev/nur-kapack";
  #inputs.kapack.nixpkgs.follows = "nixpkgs";
  # to update nix flake update --update-input oar_src 
  inputs.oar_src.url = "path:/home/auguste/dev/oar3";
  inputs.oar_src.flake = false;
  outputs = { self, nixpkgs, NUR, kapack, oar_src }:
    let
      system = "x86_64-linux";

      flavours = import ./nix/flavours.nix;

      nur = import ./nix/nur.nix {
        inherit nixpkgs system NUR;
        repoOverrides = {inherit kapack;};
      };

      extraConfigurations = [
        # add nur attribute to pkgs
        {
      nixpkgs.overlays = [ nur.overlay
        (final: prev: {
          nur.repos.kapack.oar = prev.nur.repos.kapack.oar.overrideAttrs (old: rec {
            src=oar_src;});}
        )
      ];}
    
        nur.repos.kapack.modules.oar
  ];
  
    in {
      packages.${system} = nixpkgs.lib.mapAttrs (name: flavour:
        (import ./nix/compose.nix) {
          inherit nixpkgs system extraConfigurations flavour;
        }) flavours;

      defaultPackage.${system} = self.packages.${system}.nixos-test;

    };
}
