"""C5.3 for Discourse: from the live recorder, when posts and edits were first observed versus the
pre-registered rule (venue/sources/discourse.md): existence known at created + 600 s, content at
updated + 600 s. Posts already present in a forum's first poll are not new, so they are skipped."""

import json
import sys
from datetime import datetime
from pathlib import Path

RULE_MS = 600_000
MIN_ITEMS = 30


def ms(iso):
    return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)


def polls(live_dir):
    for p in sorted(Path(live_dir).glob("sources-*.jsonl")):
        for line in open(p):
            yield json.loads(line)


def analyze(live_dir):
    seen, versions, first_poll, last_poll = {}, {}, {}, {}
    gaps, items, edits, offsets = [], [], [], []
    for poll in polls(live_dir):
        if poll["source"] == "clock" and isinstance(poll["data"].get("offset_ms"), float):
            offsets.append(abs(poll["data"]["offset_ms"]))
        if poll["source"] != "discourse" or not isinstance(poll["data"], list):
            continue
        forum = poll["key"]
        if forum in last_poll:
            gaps.append(poll["recv"] - last_poll[forum])
        last_poll[forum] = poll["recv"]
        initial = forum not in first_poll
        first_poll.setdefault(forum, poll["recv"])
        for post in poll["data"]:
            key = (forum, post["id"])
            if key not in seen:
                seen[key] = poll["recv"]
                versions[key] = (post["version"], post["updated_at"])
                if not initial:
                    lag = poll["recv"] - ms(post["created_at"])
                    items.append({"forum": forum, "id": post["id"], "lag_ms": lag, "ok": lag <= RULE_MS})
            elif (post["version"], post["updated_at"]) != versions[key]:
                versions[key] = (post["version"], post["updated_at"])
                lag = poll["recv"] - ms(post["updated_at"])
                edits.append({"forum": forum, "id": post["id"], "lag_ms": lag, "ok": lag <= RULE_MS})
    span_h = max(gaps, default=0) / 3_600_000
    return {
        "forums": sorted(first_poll),
        "new_items": len(items), "item_failures": [i for i in items if not i["ok"]],
        "edits": len(edits), "edit_failures": [e for e in edits if not e["ok"]],
        "item_slack_ms": sorted(RULE_MS - i["lag_ms"] for i in items)[:5],
        "max_poll_gap_minutes": round(span_h * 60, 1),
        "clock_offset_ms": {"max_abs": max(offsets), "n": len(offsets)} if offsets else None,
        "hours_recorded": round((max(last_poll.values(), default=0) - min(first_poll.values(), default=0)) / 3_600_000, 1),
        "validated": len(items) >= MIN_ITEMS and all(i["ok"] for i in items) and all(e["ok"] for e in edits),
    }


def reconcile(data_root, live_dir, version):
    """Re-backfill (store version `version`) against what the recorder saw live, over the live window."""
    import polars as pl

    from ingest.store import Store, live

    live, first_poll = {}, {}
    for poll in polls(live_dir):
        if poll["source"] != "discourse" or not isinstance(poll["data"], list):
            continue
        first_poll.setdefault(poll["key"], poll["recv"])
        for p in poll["data"]:
            live.setdefault((poll["key"], p["id"]), (poll["recv"], p["cooked_sha256"], ms(p["created_at"])))
    raw = Store(Path(data_root) / "sources", key=["forum", "upstream_id"]).revisions("discourse")
    latest = raw.filter(pl.col("fetchedAt") <= version).sort("fetchedAt").group_by(["forum", "upstream_id"]).last().filter(live(raw))
    backfill = {(r["forum"], r["upstream_id"]): (r["eventTime"], r["content_sha256"]) for r in latest.iter_rows(named=True)}
    window_end = max(seen for seen, _, _ in live.values()) if live else 0
    missing = [k for k in live if k not in backfill and live[k][2] >= first_poll[k[0]]]
    changed = [k for k in live if k in backfill and backfill[k][1] != live[k][1]]
    backdated = [k for k, (created, _) in backfill.items()
                 if k[0] in first_poll and first_poll[k[0]] <= created <= window_end - RULE_MS
                 and (k not in live or live[k][0] > created + RULE_MS)]
    return {"live_items": len(live), "deleted": len(missing), "edited": len(changed), "backdated": len(backdated),
            "backdated_examples": backdated[:10]}


if __name__ == "__main__":
    cmd, *args = sys.argv[1:]
    out = analyze(*args) if cmd == "analyze" else reconcile(args[0], args[1], int(args[2]))
    print(json.dumps(out, indent=1))
