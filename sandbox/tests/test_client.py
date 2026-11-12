"""The shared in-sandbox client: arity (a count or "+"), file arguments sent as text, usage otherwise."""

import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

from gate.agent.daemon import SPEC as RESEARCH
from sandbox import session

PAIR_AND_LOAD: dict[str, Any] = {"usage": "pair <a> <b>; load <file>", "commands": {"pair": [2], "load": [1, "file"]}}


def client(spec: dict[str, Any], sent: list[Any]) -> Callable[..., Any]:
    ns: dict[str, Any] = {"__name__": "client", "SPEC": spec | {"socket": "x.sock"}}
    exec((session.HERE / "client.py").read_text(), ns)

    def call(request: Any) -> str:
        sent.append(request)
        return json.dumps({"ok": True})

    ns["call"] = call
    main: Callable[..., Any] = ns["main"]
    return main


def test_arity_files_and_usage(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    sent: list[Any] = []
    research, other = client(RESEARCH, sent), client(PAIR_AND_LOAD, sent)
    a, b = tmp_path / "a.json", tmp_path / "b.json"
    a.write_text("A")
    b.write_text("B")
    assert research(["select", str(a), str(b)]) == 0 and sent[-1] == {"cmd": "select", "args": ["A", "B"]}
    assert research(["select"]) == 2 and research(["eval", str(a), str(b)]) == 2 and research(["holdout", str(a)]) == 2
    assert research(["eval", str(tmp_path / "missing")]) == 1
    assert other(["pair", "t1", "done"]) == 0 and sent[-1] == {"cmd": "pair", "args": ["t1", "done"]}
    assert other(["load", str(a)]) == 0 and sent[-1] == {"cmd": "load", "args": ["A"]}
    assert other(["load"]) == 2 and other([]) == 2
    assert "usage" in capsys.readouterr().out
