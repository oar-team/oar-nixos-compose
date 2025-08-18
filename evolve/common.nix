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

in {
  imports = [ nur.repos.kapack.modules.oar ];
  # TODO move perl dependency into oar module definition in kapack 
  environment.systemPackages = with pkgs; [ python3 vim nur.repos.kapack.oar jq hwloc ];
  
  networking.firewall.enable = false;

  users.users.user1 = { isNormalUser = true; };
  users.users.user2 = { isNormalUser = true; };

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
    extraConfig = {
      LOG_LEVEL = "3";
      HIERARCHY_LABELS = "resource_id,network_address,cpuset";
      #JOB_RESOURCE_MANAGER_FILE="/etc/oar/job_resource_manager_systemd_evolving_nixos.pl";
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

      num_nodes=$(jq '[.deployment[] | select(.role == "node")] | length'  /etc/nxc/deployment.json)
      echo $num_nodes > /etc/num_nodes

      add_resources $num_nodes $num_cores
      '';
    };
    server.host = "server";
    privateKeyFile = "/etc/privkey.snakeoil";
    publicKeyFile = "/etc/pubkey.snakeoil";
  };

}
