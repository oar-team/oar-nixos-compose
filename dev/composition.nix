{ pkgs, ... }: {

  nodes = let
    commonConfig = let
      inherit (import ./ssh-keys.nix pkgs) snakeOilPrivateKey snakeOilPublicKey;
    in {
      environment.systemPackages = with pkgs.python3Packages; [pkgs.python3 pkgs.python3Packages.sqlalchemy pkgs.nano pkgs.python3Packages.pip pkgs.bat];
      networking.firewall.enable = false;
      users.users.user1 = { isNormalUser = true; };
      users.users.user2 = { isNormalUser = true; };

      environment.etc."privkey.snakeoil" = {
        mode = "0600";
        source = snakeOilPrivateKey;
      };
      environment.etc."pubkey.snakeoil" = {
        mode = "0600";
        source = snakeOilPublicKey;
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
      services.oar = {
        # oar db passwords
        database = {
          host = "server";
          passwordFile = "/etc/oar-dbpassword";
        };
        server.host = "server";
        privateKeyFile = "/etc/privkey.snakeoil";
        publicKeyFile = "/etc/pubkey.snakeoil";
      };

      services.sshd.enable = true;
      users.users.root.password = "nixos";
      services.openssh.permitRootLogin = "yes";
    };
  in {
    # frontend = { ... }: {
    #   imports = [ commonConfig ];
    #   services.oar.client.enable = true;
    # };

    server = { ... }: {
      imports = [ commonConfig ];
      services.oar.server.enable = true;
      services.oar.dbserver.enable = true;
    };

    # node1 = { ... }: {
    #   imports = [ commonConfig ];
    #   services.oar.node = {
    #     enable = true;
    #     register = { enable = true; };
    #   };
    # };

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
