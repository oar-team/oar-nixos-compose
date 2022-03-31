{ pkgs, modulesPath, nur, ... }: {
  nodes =
    let commonConfig = import ./common_config.nix { inherit pkgs modulesPath nur; };
    in {
      frontend = { ... }: {
        imports = [ commonConfig ];
        services.oar.client.enable = true;
      };

      server = { ... }: {
        imports = [ commonConfig ];
        services.oar.server.enable = true;
        services.oar.dbserver.enable = true;
      };

      node1 = { ... }: {
        imports = [ commonConfig ];
        services.oar.node = {
          enable = true;
          register = { enable = true; };
        };
      };

      # node2 = { ... }: {
      #   imports = [ commonConfig ];
      #   services.oar.node = {
      #     enable = true;
      #     register = {
      #       enable = true;
      #     };
      #   };
      # };

    };

  testScript = ''
    frontend.succeed("true")
  '';
}
