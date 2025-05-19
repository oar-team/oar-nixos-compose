{ pkgs, modulesPath, nur, helpers, flavour, ... }: {
  roles =
    let
      commonConfig = import ./common.nix { inherit pkgs modulesPath nur flavour; };
  scripts = import ./cigri_utils.nix { inherit pkgs; };
    in {
      oar-server = { ... }: {
        imports = [ commonConfig ];
        services.oar.server.enable = true;
        services.oar.client.enable = true;
        
        services.oar.dbserver.enable = true;

        environment.etc."oar/api-users" = {
        mode = "0644";
        text = ''
          user1:$apr1$yWaXLHPA$CeVYWXBqpPdN78e5FvbY3/
          user2:$apr1$qMikYseG$VL8nyeSSmxXNe3YDOiCwr1
        '';
        };
        services.oar.web.enable = true;
        
environment.etc = {
    "cigri_job.sh" = {
      mode = "0777";
      text = builtins.readFile ./job.sh;
    };
  };
        # services.nfs.server.enable = true;

        # # Define a mount point at /srv
        # services.nfs.server.exports = ''
        # /srv *(rw, no_subtree_check,fsid=0,no_root_squash)
        # '';
        # services.nfs.server.createMountPoints = true;
        
      };

      node = { ... }: {
        imports = [ commonConfig ];
        services.oar.node = { enable = true; };
environment.etc = {
    "cigri_job.sh" = {
      mode = "0777";
      text = builtins.readFile ./job.sh;
    };
  };
      };

      cigri = { ... }: {
          imports = [
             nur.repos.kapack.modules.cigri
             nur.repos.kapack.modules.my-startup
             # commonConfig
          ];
          environment.systemPackages = [ scripts.gen_campaign
    scripts.get_oar_db_dump
    scripts.qtest
];
environment.etc = {
    "cigri_job.sh" = {
      mode = "0777";
      text = builtins.readFile ./job.sh;
    };
  };

          # services.cigri = {
          #     dbserver.enable = true;
          #     client.enable = true;
          #     server.enable = true;
          #     database.passwordFile = ./cigri-dbpassword;
          #     database.host = "cigri";
          # };
          services.logrotate.enable = false;
          services.cigri = {
              dbserver.enable = true;
              client.enable = true;
              database = {
                  host = "cigri";
                  passwordFile = ./cigri-dbpassword;
                  # package = nur.repos.kapack.postgresql;
# package = pkgs.postgresql_9_6;
              };
              server = {
                  enable = true;
                  web.enable = true;
                  host = "cigri";
                  logfile = "/tmp/cigri.log";
              };
          };
          networking.hostName = "cigri";
networking.firewall.allowedTCPPorts = [ 80 ];
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    permitRootLogin = "yes";
  };


  networking.firewall.enable = false;

 users.users = {
    user1 = { isNormalUser = true; };
    user2 = { isNormalUser = true; };
    oar = { isNormalUser = true; };
    cigri = { isSystemUser = true; };
  };
  users.users.oar.group = "oar";
  users.groups.oar = { };

  users.users.cigri.group = "cigri";
  users.groups.cigri = { };
          services.my-startup = {
              enable = true;
              path = with pkgs; [ nur.repos.kapack.cigri sudo postgresql ];
              script = ''
# Waiting cigri database is ready
                  until pg_isready -h cigri -p 5432 -U postgres
                  do
                      echo "Waiting for postgres"
                          sleep 0.5;
                  done

                  until sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw cigri
                  do
                      echo "Waiting for cigri db created"
                      sleep 0.5
                  done

                  newcluster cluster_0 http://oar-server/api/ jwt fakeuser fakepasswd "" oar-server oar3 resource_id 1 ""
                  systemctl restart cigri-server
              '';
          };

      };
    };
  
  ##############################
  # Default number for each role
  rolesDistribution = { node = 1; }; # n1 ... n8

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
