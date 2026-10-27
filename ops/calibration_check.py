"""Cross-machine test 4 (audit/crossmachine/freeze.md): the calibration path's net returns on fixed markets, as
sha256 of the returns' bytes, one line per market."""
import hashlib, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from gate import sweep

oracle = json.loads(sweep.ORACLE.read_text())
capped = json.loads(sweep.ORACLE.read_text())
capped["weight"]["args"][1]["const"] = 2.0
for program, model, beta, market, years in [(oracle, "N2", 0.025, "xc-N2-0", sweep.TRUTH_YEARS),
                                            (capped, "N2", 0.1, "xc-long-0", sweep.LONG_YEARS)]:
    r = sweep.net_returns(program, model, beta, market, years)
    print(json.dumps({"market": market, "steps": len(r), "sha256": hashlib.sha256(r.tobytes()).hexdigest()}), flush=True)
