{ pkgs, modulesPath, helpers, flavour, ... }:
let
  nbNodes = 4;
  nbNodesStr = builtins.toString nbNodes;
in

{
  #dockerPorts.frontend = [ "8443:443" "8000:80" ];
  roles =
    let
      commonConfig = import ./common_config.nix { inherit pkgs; nbNodes = nbNodesStr; };
    in {
      frontend = { ... }: {
        imports = [ commonConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.slurm.enableStools = true;
      };
      
      server = { ... }: {
        imports = [ commonConfig ];
        nxc.sharedDirs."/users".export = true;

        services.slurm.server.enable = true;
        services.slurm.dbdserver.enable = true;
        
      };
      node = { ... }: {
        imports = [ commonConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.slurm.client.enable = true;
        
      };
    };
  
  ##############################
  # Default number for each role
  rolesDistribution =  { node = nbNodes; };

  testScript = ''
  '';
}
