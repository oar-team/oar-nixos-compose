
OAR's live tests with NixOS-Compose
===================================

# Introduction
Each directory contains a non-trivial OAR examples;
To facilitate their testing and development and ensure their reproducibility, we propose the use of
[NixOS-Compose (NXC)](https://github.com/oar-team/nixos-compose).

## NixOS Compose references
- [Documentation](https://nixos-compose.gitlabpages.inria.fr/nixos-compose/)(WIP)
- [Tutorial](https://nixos-compose.gitlabpages.inria.fr/tuto-nxc/)
- [IEEE Cluster article](https://hal.archives-ouvertes.fr/hal-03723771)([bibtex](https://hal.archives-ouvertes.fr/hal-03723771v1/bibtex))

# List of  compositions
| Directory                    | Description      | Status     | CI@Grid5000 |
|------------------------------|-------------------|-----------|------------------|
| [master](master/README.md)   | follows the [OAR's master branch](https://https://github.com/oar-team/oar3)| maintained | TODO             |
| [xxx](xxx/README.md)         |                   | (WIP)     | -                |

# Requirements for local use install
- Install Nix official or Determinante version:
  - [official version](https://nixos.org/download/)
  - [Determinate version](https://docs.determinate.systems/)

- Clone this repository

# Docker
 ```bash
# Chose a variant e.g. master
cd master
# Launch bash shell with NixOS-Compose
nix develop
# Build targeted image
nxc build -b docker
# Start composition (aka docker compose)
nxc start
# In other window
cd master
nix develop
# Open terminal per nodes within tmux (terminal multiplexer)
nxc connect
# To stop from
nxc stop
```
# VM
 ```bash
cd master
nix develop
nxc build -b vm
nxc start
# In other window
cd master
nix develop
nxc connect
# To stop use Ctrl-C on nxc start process
```

# On Grid'5000@Slices testbed

⚠️: Nix is not officially supported on Grid'5000@Slices
Using NXC on Grid'5000 is subject to changes and some features are either partial or experimental. Consequently use of Nix and NXC on Grid5000 is not as smooth as one might expect.

## 1. Get Grid'5000 account
 - Go https://www.grid5000.fr/w/Grid5000:Get_an_account
 - First get some practice, begin by Getting Started page to discover Grid’5000

## 2. Install Nixos-Compose
 - Installation
 ```bash
 pip install nixos-compose
 ```
 - You might need to modify your `$PATH`:
 ```bash
 export PATH=$PATH:~/.local/bin
  ```
 - To upgrade
 ```bash
 pip install --upgrade nixos-compose
 ```
 ## 4. Install NIX with the help of Nixos-Compose
 - The following command will install a standalone and static Nix version in `~/.local/bin`
 ```bash
 nxc helper install-nix
 ```
# Use
## 1. Clone oar-nixos-compose repository on Grid'5000

```bash
git clone git@github.com:oar-team/oar-nixos-compose.git
```
## 2. Interactive session
We take master case as example.

### Build image to deploy with Kadeploy
We recommend to build on dedicated node not on frontend to avoid its overloading.
```bash
# build on dedicated node not on frontend
# reserve one node
oarsub -I
# go to master directory
cd oar-nixos-compose/master
# build default image (flavour g5k-nfs-store to fast deploying)
nxc build
```

### Deploy image on nodes

```bash
# reserve some 4 nodes for 2 hours and retrieve $OAR_JOB_ID in one step
export $(oarsub -l nodes=4,walltime=2:0 "$(nxc helper g5k_script) 2h" | grep OAR_JOB_ID)
# deploy (use last built image)
nxc start -m ./OAR.$OAR_JOB_ID.stdout -W
# connect and spawn new tmux with pane for each node
nxc connect
```
**Note:** *nxc connect* can be used to connect to only one node *nxc connect <node>*. Also **nxc connect** is really useful only if a minimal set of **[tmux](https://github.com/tmux/tmux/wiki/Getting-Started)**'s key bindings are mastered (like Ctrl-b + Up, Down, Right, Left to change pane, see tmux manual for other key bindings.

### Time to experiment
Depends of each composition.
See the README in each directory: [README](master/README.md) for concrete example.

### Terminate session
```bash
oardel $OAR_JOB_ID
```
Note: `oarstat -u` to list user's jobs.

### Generate Kadeploy image
```bash
# On builder node
cd oar-nixos-compose/master
nxc build -f g5k-image
```
### Deploy Kadeploy image
```bash
# On frontend
cd oar-nixos-compose/master
oarsub -l nodes=4,walltime=2:0 -t deploy -I
nxc start -m $OAR_NODEFILE --remote-deployment-info
nxc connect
```

## 3. Non-interactive session
TODO: We use execo

## 4. By using nix-datamove machine as remote builder (⚠️Experimental⚠️)
### Advantage:
- Faster building
### Disadvantages:
- Incomplete support, bad or missing error handling, unstable (WIP)
### Requirements
- You need to ask an NXC team member to give you access to the builder
- ⚠️ For building step you should be on Grenoble site. Building from other sites has not been tested.
- Install `setup-remote-nix.sh` on Grenoble site:
```bash
curl -L http://public.grenoble.grid5000.fr/~orichard/scripts/setup-remote-nix.sh  -o $HOME/.local/bin/setup-remote-nix.sh
chmod 755 $HOME/.local/bin/setup-remote-nix.sh
```
This script is used on a node to mount the store of nix-datamove.

###  Build image to deploy with Kadeploy
```bash
# reserve one node
oarsub -I
# mount /nix/store of nix-datamove machine
setup-remote-nix.sh
# go to master directory
cd oar-nixos-compose/master
# build default image
nxc build -f g5k-image --mounted-store-url doozer@nix-datamove
```
### Deploy Kadeploy image on nodes
```bash
# On frontend
cd oar-nixos-compose/master
oarsub -l nodes=4,walltime=2:0 -t deploy -I
nxc start -m $OAR_NODEFILE --remote-deployment-info
```

# Elements for development

## Build customization via setup.toml

**setup.toml**: is a file present in each directory. It allows to apply some selectable parameters for image building, by example to change source for specific application (useful during development or test).

Below example with two setup **g5k-dev** and **laptop** selectable by option `-s`, e.g. `nxc build -s g5k-dev` or `nxc build -s laptop`

```toml
[project]

[g5k-dev.options]
nix-flags = "--impure" # required when source is not committed (here in /home/orichard/ear)

[g5k-dev.build.nur.repos.kapack.oar]
src = "/home/orichard/ear"

[laptop.options]
nix-flags = "--impure"

[laptop.build.nur.repos.kapack.oar]
src = "/home/auguste/dev/oar"
```
The entry `[g5k-dev.build.nur.repos.kapack.oar]` specifies that the source file for EAR is located in `/home/orichard/oar` directory.

# Tips

- **tmux**: It's recommended to use **[tmux](https://github.com/tmux/tmux/wiki/Getting-Started)** on frontend to cope with connection error between Grid'5000 and the outside.

Launch a new session:

    tmux

Attach to a previous session (typically after and broken network connection)

    tmux a

Display help and keyboard shortcuts:

    CTRL-b ?

Some command shortcuts:

    CTRL-b "          split vertically
    CTRL-b %          split horizontally (left/right)

    CTRL-b left       go to pane on the left
    CTRL-b right      go to pane on the right
    CTRL-b up         go to pane on the up
    CTRL-b down       go to pane on the down

    CTRL-b x          kill current pane


- **Redeployment**: If the number of nodes is the same or lower than the deployed ones it not needed to submit a new job, just execute a new `nxc start -m NODES_FILE` command with `NODES_FILE` containing the appropriate number of machine.
