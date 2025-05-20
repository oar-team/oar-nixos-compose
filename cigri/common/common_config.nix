{ pkgs, modulesPath, lib, nur, ... }:
let
  inherit (import "${toString modulesPath}/tests/ssh-keys.nix" pkgs)
    snakeOilPrivateKey snakeOilPublicKey;
  scripts = import ./cigri_utils.nix { inherit pkgs; };
in {
  networking.firewall.enable = false;
  networking.firewall.allowedTCPPorts = [ 80 ];
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings.PermitRootLogin = "yes";
  };

  users.users = {
    user1 = { isNormalUser = true; };
    user2 = { isNormalUser = true; };
    oar = { isSystemUser = true; };
    cigri = { isSystemUser = true; };
  };
  users.users.oar.group = "oar";
  users.groups.oar = { };

  users.users.cigri.group = "cigri";
  users.groups.cigri = { };

  environment.systemPackages = with pkgs; [
    nfs-utils
    socat
    wget
    openssh
    nano
    scripts.gen_campaign
    scripts.get_oar_db_dump
    scripts.qtest
  ];

  environment.etc = {
    "cigri_job.sh" = {
      mode = "0777";
      text = builtins.readFile ./job.sh;
    };
  };
}
