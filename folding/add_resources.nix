{ pkgs, N, k, M }:

# Create N logical vnodes spread over M physical nodes.

pkgs.writers.writePython3Bin "add_resources"
{
  libraries = [ pkgs.oar ];
} ''
  import time
  import sys
  from sqlalchemy import text
  from oar.lib.tools import get_date
  from oar.lib.globals import init_and_get_session
  from oar.lib.resource_handling import resources_creation

  N = ${toString N}
  k = ${toString k}
  M = ${toString M}

  # Wait for the database to be ready.
  session = None
  for _ in range(1000):
      try:
          session = init_and_get_session()
          print(get_date(session))
          break
      except Exception:
          print("DB not ready, retrying...")
          time.sleep(0.25)
  if session is None:
      raise SystemExit("DB unreachable")

  # M physical nodes x k folding factor = N vnodes total.
  # nb_core = number of physical cores, use to set right cpuset
  # With vfactor=k, the number of vnodes per node
  num_cores = int(sys.argv[1]) if len(sys.argv) > 1 else 4
  resources_creation(session, "node", M, nb_core=num_cores, vfactor=k)

  # vnodes = resource_id (1..N), raw SQL because the column is dynamic.
  session.execute(text("UPDATE resources SET vnodes = resource_id::text"))
  session.commit()

  print(f"created {M*k} vnodes on {M} physical node(s) (k={k})")
''
