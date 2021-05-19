{
  description = "nixos-compose - composition to infrastructure";

  inputs.NUR.url = "github:nix-community/NUR";
  inputs.kapack.url = "github:oar-team/nur-kapack";
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
      packages.${system} = nixpkgs.lib.mapAttrs (name: flavour:
        (import ./nix/compose.nix) {
          inherit nixpkgs system extraConfigurations flavour;
        }) flavours;

      defaultPackage.${system} = self.packages.${system}.nixos-test;

    };
}
