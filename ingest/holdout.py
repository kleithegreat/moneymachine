"""C0.9: append the sha256 of every holdout file not yet recorded to audit/holdout.json.

Hashes file bytes without parsing them, so no holdout value is read.
"""

import hashlib
import json
import time
from pathlib import Path


def main(data_root, audit_path):
    audit = Path(audit_path)
    entries = json.loads(audit.read_text()) if audit.exists() else []
    known = {e["path"] for e in entries}
    for f in sorted((Path(data_root) / "holdout").rglob("*.parquet")):
        rel = str(f.relative_to(data_root))
        if rel not in known:
            entries.append({"path": rel, "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
                            "recorded": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})
    audit.parent.mkdir(exist_ok=True)
    audit.write_text(json.dumps(entries, indent=1) + "\n")

