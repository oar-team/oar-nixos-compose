{ pkgs, modulesPath, flavour, setup, N, k, M }:

let
  inherit (import "${toString modulesPath}/tests/ssh-keys.nix" pkgs)
    snakeOilPrivateKey snakeOilPublicKey;
  add_resources = import ./add_resources.nix { inherit pkgs N k M; };
in
{
  environment.systemPackages = with pkgs; [
    python3
    vim
    oar
    jq
    hwloc
    openmpi
    python3Packages.clustershell
  ];

  networking.firewall.enable = false;

  users.users.user1 = { isNormalUser = true; };
  users.users.user2 = { isNormalUser = true; };

  environment.etc."oar-dbpassword".text = ''
    DB_BASE_LOGIN="oar"
    DB_BASE_PASSWD="oar"
    DB_BASE_LOGIN_RO="oar_ro"
    DB_BASE_PASSWD_RO="oar_ro"
  '';

  services.oar = {
    extraConfig = {
      LOG_LEVEL = "3";

      HIERARCHY_LABELS = "resource_id,network_address,vnodes,cpuset";
      NODE_FILE_DB_FIELD_DISTINCT_VALUES = "id";

      JOB_RESOURCE_MANAGER_FILE = "/etc/oar/job_resource_manager_systemd_nixos.pl";
    };

    database = {
      host = "server";
      passwordFile = "/etc/oar-dbpassword";
      initPath = [
        pkgs.util-linux
        pkgs.gawk
        pkgs.jq
        pkgs.oar
        add_resources
      ];

      postInitCommands = ''
        num_cores=$(( $(lscpu | awk '/^Socket\(s\)/{ print $2 }') * $(lscpu | awk '/^Core\(s\) per socket/{ print $4 }') ))
        .oarproperty -a vnodes -c || echo "WARNING: .oarproperty -a vnodes failed"
        add_resources $num_cores
      '';
    };

    server.host = "server";
    privateKeyFile = "/etc/privkey.snakeoil";
    publicKeyFile = "/etc/pubkey.snakeoil";
  };

  environment.etc."privkey.snakeoil" = {
    mode = "0600";
    source = snakeOilPrivateKey;
  };
  environment.etc."pubkey.snakeoil" = {
    mode = "0600";
    text = snakeOilPublicKey;
  };
}
