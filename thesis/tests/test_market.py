"""C10.2/C10.5: the exchange adapter permits only the frozen public read types, at one fixed host."""

import pytest

from ingest import hl
from thesis import market


@pytest.mark.parametrize("kind", ["order", "cancel", "clearinghouseState", "userFills", "l2Book", "exchange", None])
def test_adapter_refuses_everything_but_the_frozen_reads(tmp_path, kind):
    x = market.Exchange(tmp_path)
    with pytest.raises(PermissionError):
        x.post({"type": kind})


def test_adapter_posts_only_to_the_public_info_endpoint(tmp_path, monkeypatch):
    sent = []

    class Response:
        status_code = 200

        def raise_for_status(self):
            pass

        def json(self):
            return {"universe": []}

    x = market.Exchange(tmp_path)
    monkeypatch.setattr(x.http, "post", lambda url, json: sent.append((url, json)) or Response())
    x.meta()
    assert sent == [(hl.URL, {"type": "meta"})] and hl.URL == "https://api.hyperliquid.xyz/info"
    assert len(list(tmp_path.glob("info-*.jsonl"))) == 1


def test_no_signing_or_exchange_endpoint_in_the_repository():
    from pathlib import Path

    repo = Path(__file__).resolve().parents[2]
    sources = [p for p in repo.rglob("*.py") if ".git" not in p.parts and "data" not in p.parts and p != Path(__file__)]
    text = "\n".join(p.read_text() for p in sources)
    for banned in ("eth_account", "eth_keys", "sign_l1_action", "private_key", "/exchange\"", "hyperliquid.exchange"):
        assert banned not in text, banned
