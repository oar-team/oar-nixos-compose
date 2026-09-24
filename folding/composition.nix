{ pkgs, modulesPath, helpers, flavour, setup, ... }:

let
  N = setup.params.nb_vnodes;
  k = setup.params.factor;
  M = assert pkgs.lib.assertMsg (k > 0 && N > 0 && pkgs.lib.mod N k == 0)
    "folding: nb_vnodes (${toString N}) must be a positive multiple of factor (${toString k})";
    N / k;
in
{
  roles =
    let
      commonConfig = import ./common.nix {
        inherit pkgs modulesPath flavour setup N k M;
      };
    in
    {
      frontend = { ... }: {
        imports = [ commonConfig ];
        services.oar.client.enable = true;
      };

      server = { ... }: {
        imports = [ commonConfig ];
        services.oar.server.enable = true;
        services.oar.dbserver.enable = true;
        services.oar.web.enable = true;
        environment.systemPackages = [ pkgs.postgresql ];

        environment.etc."oar/api-users" = {
          mode = "0644";
          text = ''
            user1:$apr1$yWaXLHPA$CeVYWXBqpPdN78e5FvbY3/
            user2:$apr1$qMikYseG$VL8nyeSSmxXNe3YDOiCwr1
          '';
        };
      };

      node = { ... }: {
        imports = [ commonConfig ];
        services.oar.node = { enable = true; };
      };
    };

  rolesDistribution = { node = M; };

  testScript = ''
    # Wait for the nodes
    frontend.wait_until_succeeds("oarnodes -s | grep -q Alive", timeout=600)
    # Job over k+1 vnodes, so on 2 nodes: run hostname on each host of the job with oarsh
    frontend.succeed("su - user1 -c \"oarsub -l vnodes=${toString (k + 1)} 'for h in \\$(sort -u \\$OAR_NODEFILE); do oarsh \\$h hostname; done'\"")
    # Wait for the end of the job and check its final state
    frontend.wait_until_succeeds("oarstat -j 1 -s | grep -qE 'Terminated|Error'", timeout=300)
    frontend.succeed("oarstat -j 1 -s | grep -q Terminated")
    # The job output (written on its first node) must list both hosts
    out = "".join(m.execute("cat /home/user1/OAR.1.stdout")[1] for m in machines if m.name.startswith("node"))
    assert "node1" in out and "node2" in out, out
  '';
}
