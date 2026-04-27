#!/usr/bin/env python
import math
import re
import subprocess
import sys
from pathlib import Path
from execo_engine import Engine, logger
from execo_g5k import (
        OarSubmission, 
        oardel, 
        oarsub, 
        wait_oar_job_start,
        )
from nixos_compose.nxc_execo import get_oar_job_nodes_nxc

class MyEngine(Engine):
    def __init__(self):
        super(MyEngine, self).__init__()
        self.oar_job_id = None
        parser = self.args_parser

        parser.add_argument(
            "-f", "--flavour", help="Nixos compose flavour", default="g5k-image", 
            choices=["docker", "vm", "g5k-image"]
        )
        # g5k-image only
        parser.add_argument("--nxc_build_file", help="Path to the NXC build file")
        parser.add_argument("-w", "--walltime", help="Grid5000 booking walltime (int in hours)")
        parser.add_argument("--site", default="grenoble")
        parser.add_argument("--cluster", default="dahu")
        parser.add_argument(
            "-k", "--keep-job",
            help="Do not delete the OAR job after execution, be it after an error or success",
            action="store_true",
        )
        parser.add_argument(
            "-j", "--job-id",
            help="When provided, the given OAR job ID is used and no further booking is done",
            type=int,
        )
        parser.add_argument(
            "-i", "--image-store-ssh", help="Remote store location via ssh (e.g. user@remote.store.org)", 
            default=""
        )


    def init(self):
        pass

    def run(self):
        N, k = read_setup_params()
        M = math.ceil(N / k)
        logger.info(f"Folding: N={N} vnodes -> M={M} node(s) (k={k}, flavour={self.args.flavour})")

        if self.args.flavour == "g5k-image":
            self._run_g5k(M)
        else:
            self._run_local(M)

    def _run_local(self, M):
        flavour = self.args.flavour
        cmd = ["nxc", "start", "-f", flavour, "-r", f"node={M}"]
        logger.info(f"Running: {' '.join(cmd)}")
        if subprocess.run(cmd).returncode != 0:
            logger.error(f"nxc start failed. Did you `nxc build -f {flavour}` ?")
            sys.exit(1)

        logger.info("")
        logger.info("Cluster up. In another terminal:")
        logger.info("    nxc connect frontend")
        logger.info("    su - user1")
        logger.info("    oarsub -I -l vnodes=2")
        logger.info("")

        try:
            input("Press Enter to stop the cluster...\n")
        except (KeyboardInterrupt, EOFError):
            pass

        logger.info("Stopping cluster")
        subprocess.run(["nxc", "stop"])

    def _run_g5k(self, M):
        if not self.args.nxc_build_file:
            logger.error("--nxc_build_file required for g5k-image")
            sys.exit(1)

        site = self.args.site
        cluster = self.args.cluster
        nb_physical_nodes = 1 + 1 + M  # frontend + server + M nodes

        roles_quantities = {
            "server":   ["server"],
            "frontend": ["frontend"],
            "node":     [f"node{i + 1}" for i in range(M)],
        }
        walltime_hours = int(self.args.walltime) if self.args.walltime else 1
        
        try:
            # Book nodes on Grid 5000 unless the ID of an existing job has been provided
            if self.args.job_id is None:
                logger.info(f"Reserving {nb_physical_nodes} machines on {site}-{cluster}")
                oar_job = reserve_nodes(
                    nb_physical_nodes, site, cluster, "deploy", walltime=walltime_hours * 60 * 60
                )
                self.oar_job_id, site = oar_job[0]
                if self.oar_job_id is None:
                    logger.error("OAR reservation failed")
                    sys.exit(1)
                wait_oar_job_start(self.oar_job_id, site)
            else:
                self.oar_job_id = self.args.job_id

            logger.info("Deploying ...")
            nodes, roles = get_oar_job_nodes_nxc(
                self.oar_job_id, site,
                flavour_name="g5k-image",
                compose_info_file=self.args.nxc_build_file,
                roles_quantities=roles_quantities,
                image_store_ssh=self.args.image_store_ssh,
            )
            logger.info(f"Done. Nodes : {nodes}")

            front = nodes["frontend"]
            if isinstance(front, list):
                front = front[0]
            logger.info("")
            logger.info(f"Frontend : ssh root@{front.address}")
            logger.info("    su - user1; oarsub -I -l vnodes=2")
            logger.info("")

            try:
                input("Press Enter to release the OAR reservation...\n")
            except (KeyboardInterrupt, EOFError):
                pass

        except FailedProcessError as e:
            logger.error(f"Failed at process {e}")
        except KeyboardInterrupt:
            logger.info("Stopping (received keyboard interrupt)")
        finally:
            if self.oar_job_id is not None and not self.args.keep_job:
                logger.info(f"Giving back the resources (OAR job ID {self.oar_job_id})")
                oardel([(self.oar_job_id, "site")])


class FailedProcessError(Exception):
    """Exception raised when an Execo process failed (meaning its attribute finished_ok is False)"""

    def __init__(self, process):
        super(Exception, self).__init__()
        self.process = process

    def __str__(self):
        return str(self.process)

def reserve_nodes(nb_nodes, site, cluster, job_type, walltime=3600):
    """
    :param walltime: the duration of the job, in seconds (or a datetime, or a string as expected by the oarsub program)
    """
    jobs = oarsub(
        [
            (
                OarSubmission(
                    resources="{{cluster='{}'}}/nodes={}".format(cluster, nb_nodes),
                    walltime=walltime,
                    job_type=[job_type],
                ),
                # additional_options = '-t exotic'),
                site,
            )
        ]
    )
    return jobs

def read_setup_params(setup_path="setup.toml"):
    text = Path(setup_path).read_text()
    N = re.search(r"^nb_vnodes\s*=\s*(\d+)", text, re.MULTILINE)
    k = re.search(r"^factor\s*=\s*(\d+)", text, re.MULTILINE)
    if not N or not k:
        logger.error(f"Cannot read params from {setup_path}")
        sys.exit(1)
    return int(N.group(1)), int(k.group(1))

if __name__ == "__main__":
    ENGINE = MyEngine()
    try:
        ENGINE.start()
    except Exception as ex:
        print(f"Failed: {ex}")
        if ENGINE.oar_job_id is not None:
            try:
                from execo_g5k import oardel
                oardel([(ENGINE.oar_job_id, None)])
            except ImportError:
                pass
