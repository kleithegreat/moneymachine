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
    gaps, items, edits = [], [], []
    for poll in polls(live_dir):
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
        "hours_recorded": round((max(last_poll.values(), default=0) - min(first_poll.values(), default=0)) / 3_600_000, 1),
        "validated": len(items) >= MIN_ITEMS and all(i["ok"] for i in items) and all(e["ok"] for e in edits),
    }


if __name__ == "__main__":
    print(json.dumps(analyze(sys.argv[1]), indent=1))
