"""C2.1 run: regression p-values and probe z-scores per null model, on the frozen parameters. Given a
data root and dataset version, the markets also replay the real forum counts and the probes include
event probes (C5.6)."""

import json
import sys
from pathlib import Path

from gate import markets, probes

MM = "kernel/target/release/mm"


def main(out, extra_programs=None, events=None):
    params = json.loads(Path("gate/nulls.json").read_text())
    cells = {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")}
    programs = probes.probes(events is not None) + (extra_programs or [])
    result = {}
    for model in ("N1", "N2", "N3"):
        p = params.get(model)
        pv = probes.regression_pvalues(model, p, events)
        z = probes.probe_zscores(MM, programs, model, p, cells, tag="-c21", events=events)
        result[model] = {"regression_p": pv, "min_p": min(pv), "z": z, "max_abs_z": max(abs(v) for v in z.values())}
        print(model, result[model]["min_p"], result[model]["max_abs_z"], flush=True)
    result["pass"] = all(result[m]["min_p"] > probes.P_MIN and result[m]["max_abs_z"] < probes.Z_MAX for m in ("N1", "N2", "N3"))
    Path(out).write_text(json.dumps(result, indent=1))
    print("pass", result["pass"])


if __name__ == "__main__":
    out, *real = sys.argv[1:]
    if real:
        coins = json.loads((Path(real[0]) / "universe.json").read_text())["universe"]
        real = markets.store_events(str(Path(real[0]) / "store"), int(real[1]), tuple(coins))
    main(out, events=real or None)
