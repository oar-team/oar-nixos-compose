{ flavour, oarServerName, ... }:
let
  permission = {
    boot.postBootCommands = ''
      chmod 777 -R /srv/shared
    '';
  };
  nfsDockerServer = {
    imports = [ permission ];
    fileSystems = {
      "/srv/shared" = {
        device = "/tmp/shared";
        options = [ "bind" ];
      };
    };
  };
  nfsDockerClient = {
    boot.postBootCommands = ''
      chmod 777 -R /data
      chmod 777 -R /srv/shared
    '';
    fileSystems = {
      "/data" = {
        device = "/tmp/shared";
        options = [ "bind" ];
      };
    };
  };
  nfsServer = {
    boot.postBootCommands = ''
      chmod 777 -R /srv
    '';
    services.nfs.server.enable = true;
    services.nfs.server.exports =
      "/srv *(rw,no_subtree_check,fsid=0,no_root_squash)";
    services.nfs.server.createMountPoints = true;
  };
  nfsClient = {
    boot.postBootCommands = ''
      chmod 777 -R /data
    '';
    fileSystems = {
      "/data" = {
        device = "${oarServerName}:/";
        fsType = "nfs";
      };
    };
  };
in {
  server = if flavour.name == "docker" then nfsDockerServer else nfsServer;
  client = if flavour.name == "docker" then nfsDockerClient else nfsClient;
}
