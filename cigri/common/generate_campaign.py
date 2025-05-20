import sys
import datetime

class Campaign:
    """
    Class describing a CiGri campaign
    """
    def __init__(self, config, base_path="/home/user1"):
        self.nb_jobs = config["nb_jobs"]
        self.sleep_time = config["sleep_time"]
        self.file_size = config["file_size"]
        self.campaign_name = f"campaign_{self.nb_jobs}j_{self.sleep_time}s_{self.file_size}M"
        # self.exec_file_path = f"{base_path}/{self.campaign_name}.sh"
        self.exec_file_path = "/etc/cigri_job.sh"
        self.campaign_file_path = f"{base_path}/{self.campaign_name}.json"

    def generate_exec_file(self):
        """
        Generate the executable for the CiGri Campaigns
        """
        write_command = ""
        if self.file_size != 0:
            write_command = f"dd if=/dev/zero of=//mnt/nfs0/file-nfs-{self.campaign_name}-$2 bs={self.file_size}M count=1 oflag=direct && rm /mnt/nfs0/file-nfs-{self.campaign_name}-$2"
        script = f"""#!/bin/bash
echo $2 > /tmp/$1
sleep $3 # {self.sleep_time}
{write_command}"""
        exec_file = open(self.exec_file_path, "w")
        exec_file.write(script)
        exec_file.close()

    def generate_campaign_file(self):
        """
        Generate the json campaign file
        """
        walltime = datetime.timedelta(seconds=self.sleep_time)
        params = ",\n\t".join(["\"param{index} {index} {sleep_time}\"".format(index=i, sleep_time=self.sleep_time) for i in range(self.nb_jobs)])
        content = f"""
{{
  "name": "{self.campaign_name}",
  "resources": "resource_id=1",
  "exec_file": "{self.exec_file_path}",
  "exec_directory": "/data",
  "test_mode": "false",
  "type": "best-effort",
  "queue": "besteffort",
  "clusters": {{
    "cluster_0": {{
      "type": "best-effort",
      "walltime": "{walltime}"
    }}
  }},
  "params": [
      {params}
  ]
}}
        """
        campaign_file = open(self.campaign_file_path, "w")
        campaign_file.write(content)
        campaign_file.close()

def main():
    args = sys.argv

    config = {
        "nb_jobs": int(args[1]),
        "sleep_time": int(args[2]),
        "file_size": int(args[3])
    }

    user_path = args[4]

    campaign = Campaign(config, user_path)
    campaign.generate_campaign_file()
    campaign.generate_exec_file()

if __name__ == "__main__":
    main()

