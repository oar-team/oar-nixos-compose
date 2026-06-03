# folding

An OAR cluster with **folding**: OAR sees `N` distinct logical vnodes, deployed
on `M = ⌈N/k⌉` physical machines.

## Concept

"Folding" means running more logical OAR nodes than physical machines. Each
physical compute node is split into `k` vnodes; OAR schedules them as if they
were independent nodes.

- The `server` and `frontend` roles each get a dedicated machine.
- The `node` role is deployed `M = ⌈N/k⌉` times. Each physical node then
  exposes `k` vnodes, for a total of `N` virtual nodes.
- Each vnode gets a distinct `cpuset`, so jobs sharing a physical node run in
  separate cgroups and never collide.

Folding is transparent to nixos-compose: it just sees a flat list of `M` nodes.
The vnode multiplication happens in the OAR database, set up at boot by
`add_resources` (see `add_resources.nix`).

## Parameters (setup.toml)

| Param         | Description                            |
| ------------- | -------------------------------------- |
| `nb_vnodes`   | **N**: number of vnodes seen by OAR    |
| `factor`      | **k**: vnodes per physical machine     |
| **M = ⌈N/k⌉** | number of physical machines deployed   |

N and k are **build-time** parameters. To change them, edit `setup.toml` (or
use `just configure N K FLAVOUR`) and rebuild.

## Supported flavours

- **vm**: local testing. Works fully, including concurrent jobs on a folded node.
- **g5k-image**: real bare-metal runs on Grid'5000. Works fully.
- **docker**: **not supported.** Use vm locally instead.

## Local usage (vm/docker)

```bash
just deploy N K vm     # configure + build + start
just configure N K vm  # edit setup.toml + rebuild only
just start vm          # start without rebuilding
just connect frontend  # root shell in the frontend VM
just stop              # stop the cluster
```

Once the cluster is up:

```bash
nxc connect frontend
su - user1
oarnodes -s              # should show N vnodes over M nodes
oarsub -I -l vnodes=2    # interactive job over 2 vnodes
```

## Grid'5000 usage

### Simple case (build on the frontend or node)

```bash
just rsync-g5k grenoble        # push the worktree to the frontend
ssh grenoble.g5k
cd folding
just g5k-deploy N K            # configure + build + reserve + deploy
```

### Remote build with remote-store-address (recommended on G5K)

On G5K the local Nix store is often too small or too slow, so the image is
built into a remote store (`<remote-store-address>`). In that case the build must
be run **outside** `nix develop` (the dev shell breaks the flake evaluation),
and the deployment passes `--image-store-ssh` so it knows where to fetch the
image.

```bash
# On a reserved node (or the frontend):

# 1. Edit setup.toml by hand to set N and k:
#      nb_vnodes = N
#      factor    = k

# 2. Build remotely, OUTSIDE nix develop:
cd Path/oar-nixos-compose/folding
setup-remote-nix.sh 
nxc build -f g5k-image --mounted-store-url <remote-store-address> 

# 3. Enter the dev shell (for just / execo / nxc) and start:
nix develop
just g5k-start            # reserves + deploys using the remote-built image
```

modifiy `just g5k-start` to passes `--image-store-ssh <remote-store-address>` as argument, so it
fetches the image from the remote store.

Once deployed, execo prints the frontend address and waits. In another
terminal:

```bash
ssh root@<frontend_address>
su - user1
oarnodes -s
oarsub -I -l vnodes=2
```

Press Enter in the execo terminal to release the reservation.
