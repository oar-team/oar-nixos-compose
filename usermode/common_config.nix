{ pkgs, nbNodes }: {

  environment.systemPackages = [ pkgs.python3 pkgs.vim pkgs.oar-usermode pkgs.jq ];
  nxc.users = { names = [ "user1" "user2" ]; prefixHome = "/users"; };

  services.slurm = {
    controlMachine = "server";
    nodeName = [ "node[1-${nbNodes}] CPUs=4 State=UNKNOWN" ];
    partitionName = [
      "default Nodes=node[1-${nbNodes}] Default=YES State=UP DefaultTime=60"
      "bebida Nodes=node[1-${nbNodes}] Default=YES MaxTime=INFINITE"
    ];
     extraConfig = ''
          SelectType=select/cons_tres
          SelectTypeParameters=CR_Core
        '';
  }; 

  # Avoid error about xauth missing...
  services.openssh.settings.X11Forwarding = false;

  services.slurm.dbdserver = let
    passFile = pkgs.writeText "dbdpassword" "password123";
  in
    {
      dbdHost = "server";
      storagePassFile = "${passFile}";
    };
  
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = pkgs.writeText "mysql-init.sql" ''
      CREATE USER 'slurm'@'localhost' IDENTIFIED BY 'password123';
      GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'localhost';
    '';
    ensureDatabases = [ "slurm_acct_db" ];
    ensureUsers = [{
      ensurePermissions = { "slurm_acct_db.*" = "ALL PRIVILEGES"; };
      name = "slurm";
    }];
    settings.mysqld = {
      # recommendations from: https://slurm.schedmd.com/accounting.html#mysql-configuration
      innodb_buffer_pool_size = "1024M";
      innodb_log_file_size = "64M";
      innodb_lock_wait_timeout = 900;
    };
  };

  systemd.services.slurmdbd.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 3;
  };
 
  systemd.services.slurmctld.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 3;
  };

  systemd.tmpfiles.rules = [
    "f /etc/munge/munge.key 0400 munge munge - mungeverryweakkeybuteasytointegratoinatest"
  ];
}
