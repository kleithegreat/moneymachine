"""C2.1 run: regression p-values and probe z-scores per null model, on the frozen parameters."""

import json
import sys
from pathlib import Path

from gate import probes

MM = "kernel/target/release/mm"


def main(out, extra_programs=None):
    params = json.loads(Path("gate/nulls.json").read_text())
    cells = {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")}
    programs = probes.probes() + (extra_programs or [])
    result = {}
    for model in ("N1", "N2", "N3"):
        p = params.get(model)
        pv = probes.regression_pvalues(model, p)
        z = probes.probe_zscores(MM, programs, model, p, cells, tag="-c21")
        result[model] = {"regression_p": pv, "min_p": min(pv), "z": z, "max_abs_z": max(abs(v) for v in z.values())}
        print(model, result[model]["min_p"], result[model]["max_abs_z"], flush=True)
    result["pass"] = all(result[m]["min_p"] > probes.P_MIN and result[m]["max_abs_z"] < probes.Z_MAX for m in ("N1", "N2", "N3"))
    Path(out).write_text(json.dumps(result, indent=1))
    print("pass", result["pass"])


if __name__ == "__main__":
    main(sys.argv[1])
