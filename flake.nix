{
  description = "Simple shell with nixos-compose";
  # nix develop
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    nixos-compose.url =
      "git+https://gitlab.inria.fr/orichard/nixos-compose.git";
    nixos-compose.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-compose }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShell.x86_64-linux = pkgs.mkShell {
        buildInputs = [ nixos-compose.defaultPackage.x86_64-linux ];
      };
    };
}
