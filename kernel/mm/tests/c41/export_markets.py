"""Export the gate's N1, N2 and N3 generator output for kernel/mm/tests/rules.rs (C4.1).

Run from the repo root: `nix develop -c python kernel/mm/tests/c41/export_markets.py`. N2 and N3 read
`data/store` through `gate/nulls.json`. Writes kernel/mm/tests/c41/{N1,N2,N3}.f64: little-endian f64
arrays open, high, low, close, volume (DAYS*6 bars x 12 coins, row-major), then funding and premium
(DAYS*24+1 hours x 12 coins). rules.rs pins each file's sha256."""

import hashlib
import sys
from pathlib import Path

import numpy as np

from gate import markets

DAYS = 30
OUT = Path(__file__).resolve().parent


def main() -> None:
    params = markets.null_params()
    for model in ("N1", "N2", "N3"):
        a = markets.generate(model, params.get(model), f"c41-{model}", DAYS)
        blob = b"".join(
            np.ascontiguousarray(a[k], dtype="<f8").tobytes()
            for k in ("open", "high", "low", "close", "volume", "funding", "premium")
        )
        (OUT / f"{model}.f64").write_bytes(blob)
        print(model, len(blob), hashlib.sha256(blob).hexdigest())


if __name__ == "__main__":
    sys.exit(main())
