{ pkgs, modulesPath, helpers, flavour, setup, ... }:

let
  N = setup.params.nb_vnodes;
  k = setup.params.factor;
  M = (N + k - 1) / k;
in
{
  roles =
    let
      commonConfig = import ./common.nix {
        inherit pkgs modulesPath flavour setup N k M;
      };
    in
    {
      frontend = { ... }: {
        imports = [ commonConfig ];
        services.oar.client.enable = true;
      };

      server = { ... }: {
        imports = [ commonConfig ];
        services.oar.server.enable = true;
        services.oar.dbserver.enable = true;
        services.oar.web.enable = true;

        environment.etc."oar/api-users" = {
          mode = "0644";
          text = ''
            user1:$apr1$yWaXLHPA$CeVYWXBqpPdN78e5FvbY3/
            user2:$apr1$qMikYseG$VL8nyeSSmxXNe3YDOiCwr1
          '';
        };
      };

      node = { ... }: {
        imports = [ commonConfig ];
        services.oar.node = { enable = true; };
      };
    };

  rolesDistribution = { node = M; };

  testScript = ''
    server.wait_for_unit("oar-server.service")
    frontend.wait_for_unit("multi-user.target")
    frontend.succeed("oarnodes -l | wc -l | grep -q ${toString N}")
  '';
}
