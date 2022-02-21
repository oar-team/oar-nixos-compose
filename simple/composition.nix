{ pkgs, modulesPath, ... }: {
  nodes =
    let commonConfig = import ./common_config.nix { inherit pkgs modulesPath; };
    in {
      frontend = { ... }: {
        imports = [ commonConfig ];
        services.oar.client.enable = true;
      };

      server = { ... }: {
        imports = [ commonConfig ];
        services.oar.server.enable = true;
        services.oar.dbserver.enable = true;
        services.oar.web.enable = true;
        services.oar.web.monika.enable = true;
        services.oar.web.drawgantt.enable = true;
      };

      node1 = { ... }: {
        imports = [ commonConfig ];
        services.oar.node = {
          enable = true;
          register = { enable = true; };
        };
      };

      node2 = { ... }: {
         imports = [ commonConfig ];
         services.oar.node = {
           enable = true;
           register = {
             enable = true;
           };
        };
      };

    };

  testScript = ''
    frontend.succeed("true")
  '';
}
