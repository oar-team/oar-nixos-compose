# CiGri and OAR


## Build

```console
nxc build -f <flavour>
```

## Start

```console
nxc start
```

## Connect

```console
nxc connect cigri
```

## Setting up permission for the NFS

TODO: see if we can do this in the composition instead... :(

```console
[root@cigri:/]# ssh node1 chmod 777 /data
[root@cigri:/]# chmod 777 /data
```

## Generating a dummy campaign

```console
[root@cigri:/]# su user1
[user1@cigri:/]# cd /home/user1
[user1@cigri:~]# gen_campaign 10 60 0
```

## Submitting the campaign

```console
[user1@cigri:~]# gridsub -f campaign_10j_60s_0M.json
[user1@cigri:~]# gridstat
```
