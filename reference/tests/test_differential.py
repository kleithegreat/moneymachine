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


def test_an_interrupted_run_resumes_where_it_stopped(tmp_path, monkeypatch):
    import json

    import pytest

    items = [{"name": f"p{i}", "program": "{}", "markets": ["A", "B"] if i % 2 else ["A"]} for i in range(150)]
    corpus = "".join(json.dumps(it) + "\n" for it in items)
    (tmp_path / d.CORPUS).write_text(corpus)
    (tmp_path / d.MANIFEST).write_text(json.dumps({"corpus_sha256": d.sha(corpus), "seed": 1, "generated": 150, "minimum": 1,
                                                   "markets": {"A": {"market_sha256": "a", "version": 1},
                                                               "B": {"market_sha256": "b", "version": 1}}}))
    monkeypatch.setattr(d, "build", lambda: None)
    monkeypatch.setattr(d, "markets_of", lambda seed, work: {"A": work / "A", "B": work / "B"})
    monkeypatch.setattr(d, "market_hash", lambda root: root.name.lower())
    monkeypatch.setattr(d, "complete", lambda *a: [])
    monkeypatch.setattr(d, "verdict", lambda i, it, work: {"i": i, "name": it["name"], "mm": "ok", "ref": "ok"})
    ran = []

    def chunk(names, texts, market, root, version, tmp):
        if len(ran) == 2 and not ran[-1].startswith("again"):
            raise RuntimeError("interrupted")
        ran.append(f"{market}:{names[0]}")
        return [(n, market, True, {}, {"runs": 1}) for n in names]

    monkeypatch.setattr(d, "chunk", chunk)
    monkeypatch.setattr("gate.compute.workers", lambda per_task: 1)
    out = tmp_path / "report.json"
    with pytest.raises(RuntimeError):
        d.run(out, audit=tmp_path)
    first = list(ran)
    ran.append("again")
    report = d.run(out, audit=tmp_path)
    redone = ran[len(first) + 1:]
    assert report == {"programs": 150, "runs": 225, "pass": True, "verdict_disagreements": 0, "run_disagreements": 0}
    assert not set(first) & set(redone) and len(first) + len(redone) == 5
