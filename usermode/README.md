
OAR's Usermode under Slurm Management
=================================================

*Warning it's an experimental POC*, the mapping beetween OAR and Slurm is very sensitive to Slurm configuration. In particular if we want to manage at Socket/CPU/core granularities you must be very carefull and conduct extensive tests adaptation...


*Limitation* In short only submission of OAR's batch job is supported 

## Helpers command oar-usermode

Options:

  -c, --create-db        Create database
  -b, --base-configfile  Copy base configuration file ('oar_usermode.conf')
  -n, --nodes TEXT       nodes to declare in database following nodeset
                         formate (ex: node[1,6-7])
  -s, --skip             skip the first node from nodes (usually reserved to
                         OAR services
  -o, --nb-core INTEGER  Number of cores for each node
  --help                 Show this message and exit.

## Without Slurm

```bash
 nxc -l user1 frontend frontend

 # In one terminal
 cd

 mkdir -p /tmp/oar/admission_rules.d
 export OAR_CONFIG_FILE=oar_usermode.conf OARDIR="" OARDO_USER=$(whoami)
 
 # Copy oar_usermode.conf example from source
 # Create db_oar.sqlite file db 
 # Fill DB: 2 queues default and admin, 5 nodes with number of detected core
 
 oar-usermode -b -c
 
 # Check DB by listing nodes (note: the dot before command)
 .oarnodes

 # launch all oar services (server parts)
 oar-almighty

 # In the second terminal
 cd
 export OAR_CONFIG_FILE=oar_usermode.conf OARDIR="" OARDO_USER=$(whoami)
     
.oarsub -l nodes=1 "env | grep OAR"

# check stdout of job and note the addtionnal OAR variables to help mapping
# with other system
cat OAR.*.stdout
...
OAR_NODESET=node[1-4]
OAR_NUMBER_RESOURCE=16
OAR_JOB_ID=2
OAR_NUMBER_NODE=4
OAR_RATIO_RESOURCE_NODE=4

```

## With Slurm inteactive session

```bash
 nxc -l user1 frontend frontend
 cd
 
 salloc --nodes=4 --time=01:00:00  
 
 # show the allocated nodes and job_id
 echo $SLURM_JOB_NODELIST
 echo $SLURM_JOBID=1
 
 
 mkdir -p /tmp/oar/admission_rules.d
 export OAR_CONFIG_FILE=oar_usermode.conf OARDIR="" OARDO_USER=$(whoami)
 
 # Create and file DB file (db_oar.sqlite)  
 # Take node liste from Slurm allocation without first node (-s option: swkip the first node)
 
 oar-usermode -b -c -s -n $SLURM_JOB_NODELIST
 
 # Checke DB by listing nodes (note: the dot before command)
 .oarnodes

 # TODO srun -s -N1 --jobid=1 --nodelist=node1  --pty bash 
 # launch all oar services (server parts)
 export OAR_CONFIG_FILE=oar_usermode.conf OARDIR="" OARDO_USER=$(whoami)
 oar-almighty

 # In the second terminal
 # TODO shared the same node where OAR's server run
 # srun -s -N1 --jobid=1 --nodelist=node1  --pty bash 
 cd
 export OAR_CONFIG_FILE=oar_usermode.conf OARDIR="" OARDO_USER=$(whoami)
 
# Node single quote to replace OAR var at submittion
# -N$OAR_NUMBER_NODE-$OAR_NUMBER_NODE to force then number of nodes
# --jobid=1 is the SLURM_JOBID
.oarsub -l nodes=2 'srun --jobid=1 -N$OAR_NUMBER_NODE-$OAR_NUMBER_NODE --nodelist=$OAR_NODESET hostname'

echo OAR.*.stdout
node3
node2
# 

 ```

