{ pkgs, modulesPath, nur, helpers, flavour, ... }: {
  roles =
    let
      commonConfig = import ./common.nix { inherit pkgs modulesPath nur flavour; };
    in {
      frontend = { ... }: {
        imports = [ commonConfig ];
        services.oar.client.enable = true;
      };
      server = { ... }: {
        imports = [ commonConfig ];
        services.oar.server.enable = true;
        #services.oar.package = pkgs.oar-with-plugins;
        
        services.oar.dbserver.enable = true;
        
      };
      node = { ... }: {
        imports = [ commonConfig ];
        services.oar.node = { enable = true; };
      };
    };
  
  ##############################
  # Default number for each role
  rolesDistribution = { node = 2; }; # n1 ... n8

  testScript = ''
    frontend.succeed("true")
    # Prepare a simple script which execute cg.C.mpi 
    frontend.succeed('echo "mpirun --hostfile \$OAR_NODEFILE -mca pls_rsh_agent oarsh -mca btl tcp,self cg.C.mpi" > /users/user1/test.sh')
    # Set rigth and owner of script
    frontend.succeed("chmod 755 /users/user1/test.sh && chown user1 /users/user1/test.sh")
    # Submit job with script under user1
    frontend.succeed('su - user1 -c "cd && oarsub -l nodes=2 ./test.sh"')
    # Wait output job file 
    frontend.wait_for_file('/users/user1/OAR.1.stdout')
    # Check job's final state
    frontend.succeed("oarstat -j 1 -s | grep Terminated")
  '';
}
