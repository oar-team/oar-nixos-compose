{
  description = "OAR - simple setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack/oar";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nxc, NUR, kapack}:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      conf_kapack = { oar = { src=/home/auguste/dev/oar3;}; };
      conf_repos = { kapack = { oar = { src=/home/auguste/dev/oar3;}; }; };

      kapack_ = "kapack";
      oar_="oar";

      mapListToAttrs = op: list:
        let
          len = builtins.length list;
          g = n: s:
            if n == len 
            then s
            else g (n+1) (s // (op (builtins.elemAt list n)));
        in
          g 0 {};

      nur = nxc.lib.nur {
        inherit nixpkgs system NUR;
        repoOverrides = { inherit kapack; };
   };
  
      extraConfigurations = [
        # add nur attribute to pkgs
        { nixpkgs.overlays = [ nur.overlay
                               (self: super: 
                                 let
                                   repos = builtins.attrNames conf_repos;
                                   overrides = repo: builtins.mapAttrs (name: value: super.nur.repos.${repo}.${name}.overrideAttrs (old: value)) conf_repos.${repo};
                                   
                                   #overrides_nur_repos =  builtins.mapAttrs (repos: nur_pkgs: 
                                 in
                                   mapListToAttrs (repo: {nur.repos.${repo} = super.nur.repos.${repo} // (overrides repo);}) repos 
                               )
                                
                                # (self: super: 
                                #   let
                                    
                                #     overrides = builtins.mapAttrs (name: value: super.nur.repos.kapack.${name}.overrideAttrs (old: value)) conf_kapack;

                                #     #overrides_nur_repos =  builtins.mapAttrs (repos: nur_pkgs: 
                                #   in
                                #     {
                                #       nur.repos.${kapack_} = super.nur.repos.${kapack_} // overrides;
                                #     }
                                # )
                               
                               # (self: super: 
                               #   let
                               #     overrides = builtins.mapAttrs (name: value: super.nur.repos.kapack.${name}.overrideAttrs (old: value)) conf_kapack;                                                                  in
                               #                                      {
                               #   nur.repos.kapack = super.nur.repos.kapack // overrides;
                               #                                      }
                               # )
                               
                               # (self: super: {
#                                  nur.repos.kapack = super.nur.repos.kapack // { ${oar_}=super.nur.repos.kapack.${oar_}.overrideAttrs (old: rec {src=/home/auguste/dev/oar3;});
# };}
#                                )
                               #                                (self: super: {
                               #   nur.repos.kapack = super.nur.repos.kapack // { oar=super.nur.repos.kapack.oar.overrideAttrs (old: rec {src=/home/auguste/dev/oar3;});
                               # };}
                               #                                )
                             ]; }
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
