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
    postgresql
    openmpi
    python3Packages.clustershell
  ];

  networking.firewall.enable = false;

  users.users.user1 = { isNormalUser = true; };
  users.users.user2 = { isNormalUser = true; };

  # Distribute the snakeoil key to the users for passwordless user-to-user SSH
  # TO BE REMOVE : should work without it
  users.users.user1.openssh.authorizedKeys.keys = [ snakeOilPublicKey ];
  users.users.user2.openssh.authorizedKeys.keys = [ snakeOilPublicKey ];

  systemd.tmpfiles.rules = [
    "d /home/user1/.ssh 0700 user1 users -"
    "C+ /home/user1/.ssh/id_rsa     0600 user1 users - /etc/privkey.snakeoil"
    "C+ /home/user1/.ssh/id_rsa.pub 0644 user1 users - /etc/pubkey.snakeoil"

    "d /home/user2/.ssh 0700 user2 users -"
    "C+ /home/user2/.ssh/id_rsa     0600 user2 users - /etc/privkey.snakeoil"
    "C+ /home/user2/.ssh/id_rsa.pub 0644 user2 users - /etc/pubkey.snakeoil"
  ];

  programs.ssh.extraConfig = ''
    Host *
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
  '';

  services.openssh.extraConfig = ''
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
    AuthorizedKeysCommandUser nobody
  '';

  environment.etc."privkey.snakeoil" = {
    mode = "0600";
    source = snakeOilPrivateKey;
  };
  environment.etc."pubkey.snakeoil" = {
    mode = "0600";
    text = snakeOilPublicKey;
  };

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
        pkgs.postgresql
        add_resources
      ];

      postInitCommands = ''
        num_cores=$(( $(lscpu | awk '/^Socket\(s\)/{ print $2 }') * $(lscpu | awk '/^Core\(s\) per socket/{ print $4 }') ))
        export PGPASSWORD=$DB_BASE_PASSWD
        ${pkgs.postgresql}/bin/psql -U $DB_BASE_LOGIN -h localhost -d oar \
          -c "ALTER TABLE resources ADD COLUMN IF NOT EXISTS vnodes VARCHAR(255);" \
          || { echo "FATAL: ALTER TABLE vnodes failed"; exit 1; }
        add_resources $num_cores
      '';
    };

    server.host = "server";
    privateKeyFile = "/etc/privkey.snakeoil";
    publicKeyFile = "/etc/pubkey.snakeoil";
  };

  # OAR may mark freshly created nodes as "Suspected" at boot. This service
  # forces every node back to "Alive" once oar-server is ready. Runs on the
  # server host only.
  systemd.services.oar-wake-nodes = {
    description = "Wake up Suspected OAR nodes after boot";
    after = [ "oar-server.service" "oar-db-init.service" ];
    requires = [ "oar-server.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.bash}/bin/bash -c '[ \"$(hostname)\" = \"server\" ] || exit 0'";
      ExecStart = "${pkgs.bash}/bin/bash -c '"
        + "for i in $(seq 1 30); do "
        + "  ${pkgs.oar}/bin/oarnodes -s >/dev/null 2>&1 && break; "
        + "  sleep 1; "
        + "done; "
        + "for n in $(${pkgs.oar}/bin/oarnodes -l 2>/dev/null | sort -u); do "
        + "  ${pkgs.oar}/bin/oarnodesetting -h \"$n\" -s Alive || true; "
        + "done"
        + "'";
    };
  };
}
