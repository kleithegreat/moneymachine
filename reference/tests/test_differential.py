"""The differential harness's own checks: stream diagnostics locate the first discrete and numeric difference,
and the inventory names what a corpus lacks."""

import struct

from reference import differential as d


def stream(values):
    return b"".join(b"\0" if v is None else b"\1" + struct.pack("<d", v) for v in values)


def test_stream_divergence_locates_the_first_differences(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    a.write_bytes(stream([1.0, None, 2.0, 3.0, 4.0, -0.0]))
    b.write_bytes(stream([1.0, 5.0, 2.0, 3.0, 4.0, 0.0]))
    first = d.stream_divergence(a, b, nodes=2, coins=3)
    assert first["discrete"][:2] == ("node definedness", (0, 0, 1))
    assert first["numeric"][:2] == ("node value bits", (0, 1, 2))
    b.write_bytes(stream([1.0, None, 2.0]))
    assert d.stream_divergence(a, b, 2, 3)["discrete"][0] == "stream length"


def test_the_inventory_names_what_is_missing():
    items = [{"name": k, "markets": ms} for k, ms in d.expected().items()]
    items += [{"name": f"gen-{i}", "program": str(i), "markets": list(d.NULLS)} for i in range(1000)]
    assert d.complete(items, 1000) == []
    assert d.complete(items[1:], 1000) and d.complete(items[:-1], 1000)
    dup = items[:-1] + [{"name": "gen-999", "program": "0", "markets": list(d.NULLS)}]
    assert any("distinct" in m for m in d.complete(dup, 1000))
    moved = [dict(it, markets=["edge"]) if it["name"] == "case-op-add" else it for it in items]
    assert any("case-op-add" in m for m in d.complete(moved, 1000))
