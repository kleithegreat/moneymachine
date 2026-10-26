"""The transcript audit counts client invocations in the Bash commands that ran."""

import json

from sandbox import session


def test_client_calls_count_invocations_in_commands_that_ran(tmp_path):
    bash = lambda i, cmd: {"type": "tool_use", "id": i, "name": "Bash", "input": {"command": cmd}}
    lines = [{"type": "assistant", "message": {"content": [bash("a", "./c markets; ./c positions"), bash("b", "./c fetch x | python3 -")]}},
             {"type": "assistant", "message": {"content": [bash("d", "./c prices BTC"), {"type": "tool_use", "id": "e", "name": "Read", "input": {}}]}},
             {"type": "result", "permission_denials": [{"tool_name": "Bash", "tool_use_id": "b"}]}]
    t = tmp_path / "transcript.jsonl"
    t.write_text("".join(json.dumps(l) + "\n" for l in lines))
    assert session.tool_use(t, "c") == {"tools": ["Bash", "Read"], "client_calls": 3, "outside_permitted": [], "denials": 1}
