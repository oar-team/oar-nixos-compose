{ pkgs, modulesPath, nur, flavour }:
let
  inherit (import "${toString modulesPath}/tests/ssh-keys.nix" pkgs)
    snakeOilPrivateKey snakeOilPublicKey;

  add_resources = pkgs.writers.writePython3Bin "add_resources" {
    libraries = [ pkgs.nur.repos.kapack.oar ]; } ''
    from oar.lib.tools import get_date
    from oar.lib.resource_handling import resources_creation
    from oar.lib.globals import init_and_get_session
    import sys
    import time
    r = True
    n_try = 10000


    session = None
    while n_try > 0 and r:
        n_try = n_try - 1
        try:
            session = init_and_get_session()
            print(get_date(session))  # date took from db (test connection)
            r = False
        except Exception:
            print("DB is not ready")
            time.sleep(0.25)

    if session:
        resources_creation(session, "node", int(sys.argv[1]), int(sys.argv[2]))
        print("resource created")
    else:
        print("resource creation failed")
  '';

  # openmpiNoOPA = pkgs.openmpi.override { fabricSupport = false; };
  # npbNoOPA = pkgs.nur.repos.kapack.npb.override (oldAttrs: rec { openmpi = openmpiNoOPA; });

  prepare_cgroup = pkgs.writeShellScript "prepare_cgroup"
  ''
  # This script prepopulates OAR cgroup directory hierarchy, as used in the
  # job_resource_manager_cgroups.pl script, in order to have nodes use different
  # subdirectories and avoid conflitcs due to having all nodes actually running on
  # the same host machine

  OS_CGROUPS_PATH="/sys/fs/cgroup"
  CGROUP_SUBSYSTEMS="cpuset cpu cpuacct devices freezer blkio"
  if [ -e "$OS_CGROUPS_PATH/memory" ]; then
    CGROUP_SUBSYSTEMS="$CGROUP_SUBSYSTEMS memory"
  fi
  CGROUP_DIRECTORY_COLLECTION_LINKS="/dev/oar_cgroups_links"


  if [ "$1" = "init" ]; then
      mkdir -p $CGROUP_DIRECTORY_COLLECTION_LINKS && \
      for s in $CGROUP_SUBSYSTEMS; do
        mkdir -p $OS_CGROUPS_PATH/$s/oardocker/$HOSTNAME
        ln -s $OS_CGROUPS_PATH/$s/oardocker/$HOSTNAME $CGROUP_DIRECTORY_COLLECTION_LINKS/$s
      done
      ln -s $OS_CGROUPS_PATH/cpuset/oardocker/$HOSTNAME /dev/cpuset

      cat $OS_CGROUPS_PATH/cpuset/cpuset.cpus > $OS_CGROUPS_PATH/cpuset/oardocker/cpuset.cpus
      cat $OS_CGROUPS_PATH/cpuset/cpuset.mems > $OS_CGROUPS_PATH/cpuset/oardocker/cpuset.mems
      /bin/echo 0 > $OS_CGROUPS_PATH/cpuset/oardocker/cpuset.cpu_exclusive
      /bin/echo 1000 > $OS_CGROUPS_PATH/cpuset/oardocker/notify_on_release

      cat $OS_CGROUPS_PATH/cpuset/oardocker/cpuset.cpus > $OS_CGROUPS_PATH/cpuset/oardocker/$HOSTNAME/cpuset.cpus
      cat $OS_CGROUPS_PATH/cpuset/oardocker/cpuset.mems > $OS_CGROUPS_PATH/cpuset/oardocker/$HOSTNAME/cpuset.mems
      /bin/echo 0 > $OS_CGROUPS_PATH/cpuset/oardocker/$HOSTNAME/cpuset.cpu_exclusive
      /bin/echo 0 > $OS_CGROUPS_PATH/cpuset/oardocker/$HOSTNAME/notify_on_release
      /bin/echo 1000 > $OS_CGROUPS_PATH/blkio/oardocker/$HOSTNAME/blkio.weight
  elif [ "$1" = "clean" ]; then
      if [ "$HOSTNAME" = "node1" ]; then
          CGROOT="$OS_CGROUPS_PATH/cpuset/oardocker/"

          if ! [ -d $CGROOT ]; then
            echo "No such directory: $CGROOT"
            exit 0;
          fi

          echo "kill all cgroup tasks"
          while read task; do
              echo "kill -9 $task"
              kill -9 $task
          done < <(find $CGROOT -name tasks -exec cat {} \;)

          wait
          echo "Wipe all cgroup content"
          find $CGROOT -depth -type d -exec rmdir {} \;

          echo "Cgroup is cleanded!"
      fi
  fi

  exit 0
  '';

in {
  imports = [ nur.repos.kapack.modules.oar ];
  environment.systemPackages = [ pkgs.exa pkgs.python3 pkgs.nano pkgs.vim pkgs.nur.repos.kapack.oar pkgs.jq ];
  
  networking.firewall.enable = false;

  users.users.user1 = { isNormalUser = true; };
  users.users.user2 = { isNormalUser = true; };

  # systemd.services.oar-cgroup = {
  #   enable = flavour.name == "docker";
  #   serviceConfig = {
  #      ExecStart = "${prepare_cgroup} init";
  #      ExecStop = "${prepare_cgroup} clean";
  #      KillMode = "process";
  #      RemainAfterExit = "on";
  #   };
  #   wantedBy = [ "network.target" ];
  #   before = [ "network.target" ];
  #   serviceConfig.Type = "oneshot";
  # };

  services.openssh.extraConfig = ''
     AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
     AuthorizedKeysCommandUser nobody
  '';

  # security.pam.loginLimits = [
  #   { domain = "*"; item = "memlock"; type = "-"; value = "unlimited"; }
  # ];

  environment.etc."privkey.snakeoil" = {
    mode = "0600";
    source = snakeOilPrivateKey;
  };
  environment.etc."pubkey.snakeoil" = {
    mode = "0600";
    #source = snakeOilPublicKey;
    text = snakeOilPublicKey;
  };

  environment.etc."oar-dbpassword".text = ''
    # DataBase user name
    DB_BASE_LOGIN="oar"

    # DataBase user password
    DB_BASE_PASSWD="oar"

    # DataBase read only user name
    DB_BASE_LOGIN_RO="oar_ro"

    # DataBase read only user password
    DB_BASE_PASSWD_RO="oar_ro"
  '';


  # environment.etc."oar-quotas.json" = {
  #   text = ''
  #       {
  #         "quotas": {
  #           "*,*,*,*": [-1,2,-1],
  #           "*,*,*,user1": [2,-1,-1]
  #         }
  #       }
  #     '';
  #   mode = "0777";
  # };

  services.oar = {
    #clipackage =  pkgs.nur.repos.kapack.oars;
    extraConfig = {
      LOG_LEVEL = "3";
      HIERARCHY_LABELS = "resource_id,network_address,cpuset";
      #JOB_RESOURCE_MANAGER_FILE="/etc/oar/job_resource_manager_evolving_nixos.pl";
      #QUOTAS = "yes";
      #QUOTAS_CONF_FILE="/etc/oar-quotas.json";
      #EXTRA_METASCHED = "dyn_rm";
    };

    # oar db passwords
    database = {
      host = "server";
      passwordFile = "/etc/oar-dbpassword";
      initPath = [ pkgs.util-linux pkgs.gawk pkgs.jq add_resources ];
      postInitCommands = ''
      num_cores=$(( $(lscpu | awk '/^Socket\(s\)/{ print $2 }') * $(lscpu | awk '/^Core\(s\) per socket/{ print $4 }') ))
      echo $num_cores > /etc/num_cores

      if [[ -f /etc/nxc/deployment-hosts ]]; then
        num_nodes=$(grep node /etc/nxc/deployment-hosts | wc -l)
      else
        num_nodes=$(jq -r '[.nodes[] | select(contains("node"))]| length' /etc/nxc/deployment.json)
      fi
      echo $num_nodes > /etc/num_nodes

      add_resources $num_nodes $num_cores
      '';
    };
    server.host = "server";
    privateKeyFile = "/etc/privkey.snakeoil";
    publicKeyFile = "/etc/pubkey.snakeoil";
  };

}
