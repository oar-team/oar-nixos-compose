{ pkgs, ... }:

{
  gen_campaign = pkgs.writeScriptBin "gen_campaign" ''
    NB_JOBS=$1
    SLEEP_TIME=$2
    FILE_SIZE=$3

    ${pkgs.python3}/bin/python3 ${./generate_campaign.py} $NB_JOBS $SLEEP_TIME $FILE_SIZE $HOME
  '';

  get_oar_db_dump = pkgs.writeScriptBin "dump_oar" ''
    sudo -u oar psql -c "copy (
      select job_id,job_name,submission_time,start_time,stop_time,resources.resource_id,jobs.state
        FROM jobs, assigned_resources, moldable_job_descriptions, resources
        WHERE jobs.assigned_moldable_job = moldable_job_descriptions.moldable_id
            AND resources.type = 'default'
            AND assigned_resources.moldable_job_id = moldable_job_descriptions.moldable_id
            AND resources.resource_id = assigned_resources.resource_id
      )  to STDOUT with csv"
  '';
  
  qtest = pkgs.writeScriptBin "qtest" ''
    cd /home/user1
    sudo -u user1 gen_campaign 1000 60 0
    sudo -u user1 gridsub -f /home/user1/campaign_1000j_60s_0M.json
    echo "{\"type\":\"pi_ff\",\"alpha\": 0.5, \"rmax\": 16, \"kp\": 0.4, \"ki\": 0.8, \"ref\": 32, \"horizon\": 120}" > /tmp/config.json
    tail -f /tmp/cigri.log
  '';
}

