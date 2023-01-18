{ pkgs, modulesPath, nur, ... }: {
  roles =
    let commonConfig = import ./common_config.nix { inherit pkgs modulesPath nur; };
    in {
      frontend = { ... }: {
        imports = [ commonConfig ];
        nxc.sharedDirs."/users".server = "server";
        services.oar.client.enable = true;
      };

      server = { ... }: {
        imports = [ commonConfig ];
        nxc.sharedDirs."/users".export = true;
        
        services.oar.server.enable = true;
        services.oar.dbserver.enable = true;
      };

      node = { ... }: {
        imports = [ commonConfig ];
        nxc.sharedDirs."/users".server = "server";
        
        services.oar.node = {
          enable = true;
          register = { enable = true; };
        };
      };
    };
  
  rolesDistribution = { node = 2; };

  testScript = ''
    frontend.succeed("true")
  '';
}
