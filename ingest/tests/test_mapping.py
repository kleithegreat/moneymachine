"""C5.1 golden set: known rebrands and collisions resolve as declared (mapping keyed by forum host)."""

import json
from pathlib import Path

MAP = Path(__file__).resolve().parents[2] / "venue/sources/discourse_map.json"
SNAP = Path(__file__).resolve().parents[2] / "venue/sources/snapshot_map.json"


def test_golden_set():
    forum = {r["forum"]: r["coin"] for r in json.loads(MAP.read_text())["rows"]}
    space = {r["space"]: r["coin"] for r in json.loads(SNAP.read_text())["rows"]}
    assert forum == {"delvingbitcoin.org": "BTC"} and space == {"aavedao.eth": "AAVE"}
    assert "aave.eth" not in space
    assert not any(c in forum.values() for c in ("ETH", "BNB", "FTM", "WLD", "kPEPE", "WIF", "POPCAT"))
    assert len(set(forum)) == len(forum) and all(r["valid_from"] is None for r in json.loads(MAP.read_text())["rows"])
