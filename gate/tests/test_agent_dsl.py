import hashlib
from pathlib import Path


def test_agent_dsl_is_frozen():
    dsl = Path(__file__).resolve().parents[2] / "kernel/DSL.md"
    assert (
        hashlib.sha256(dsl.read_bytes()).hexdigest()
        == "8cfb48160a3cdc9e8d5ccb9ca12f04bf925e4cde4fe004e679485279bc28646b"
    )
