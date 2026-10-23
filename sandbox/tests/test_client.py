"""The shared in-sandbox client: arity (a count or "+"), file arguments sent as text, usage otherwise."""

import json

from sandbox import session
from gate.agent.daemon import SPEC as RESEARCH
from thesis.daemon import SPEC as THESIS


def client(spec, sent):
    ns = {"__name__": "client", "SPEC": spec | {"socket": "x.sock"}}
    exec((session.HERE / "client.py").read_text(), ns)
    ns["call"] = lambda req: (sent.append(req), json.dumps({"ok": True}))[1]
    return ns["main"]


def test_arity_files_and_usage(tmp_path, capsys):
    sent = []
    research, thesis = client(RESEARCH, sent), client(THESIS, sent)
    a, b = tmp_path / "a.json", tmp_path / "b.json"
    a.write_text("A")
    b.write_text("B")
    assert research(["select", str(a), str(b)]) == 0 and sent[-1] == {"cmd": "select", "args": ["A", "B"]}
    assert research(["select"]) == 2 and research(["eval", str(a), str(b)]) == 2 and research(["holdout", str(a)]) == 2
    assert research(["eval", str(tmp_path / "missing")]) == 1
    assert thesis(["exit", "t1", "done"]) == 0 and sent[-1] == {"cmd": "exit", "args": ["t1", "done"]}
    assert thesis(["register", str(a)]) == 0 and sent[-1] == {"cmd": "register", "args": ["A"]}
    assert thesis(["fetch"]) == 2 and thesis([]) == 2
    assert "usage" in capsys.readouterr().out
