{
  description = "OAR - from master";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git?ref=25.05";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    kapack.url = "gitlab:kairns/kapack?host=gricad-gitlab.univ-grenoble-alpes.fr";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-master.url = "github:NixOS/nixpkgs";
  };

  outputs = {nixpkgs, nxc, kapack, nixpkgs-master, ...}:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib; 
    in {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system;
        composition = ./composition.nix;
        setup = ./setup.toml;
        extraConfigurations = builtins.attrValues kapack.nixosModules;
        #overlays = [
        #   (self: super: {
        #      hwloc = nixpkgs-master.legacyPackages.${system}.hwloc;
        #   })
        #];

				overlays = [
           ( _: _: {
             hwloc = nixpkgs-master.legacyPackages.${system}.hwloc;
           })
           (_: _: kapack.packages.${system})
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
          yq-go
          qemu_kvm
          vde2
          tmux
          nxc.defaultPackage.${system}
        ];
      };
    };
}

