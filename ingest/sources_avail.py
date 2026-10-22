"""C5.3's reported figures (stage 5 amendment of 2026-10-22: both sources are prospective, so these are reported,
not judged), per source over its whole live recording. A new item is one first observed in a poll after its key's
first poll; an edit is a later poll showing a changed revision. The operative rule makes an item known `margin` ms
after its first observation, so its slack is that margin by construction. The claimed time's lag (first observed
minus claimed creation or update) is reported for information; for Discourse, against the rejected 600 s rule."""

from pathlib import Path

from ingest.events import SOURCES, polls
from ingest.live import ms
from ingest.policy import HOUR

RULE_MS = 600_000
FIELDS = {"discourse": (lambda p: ms(p["created_at"]), lambda p: (p["version"], p["updated_at"]), lambda p: ms(p["updated_at"])),
          "snapshot": (lambda p: p["created"] * 1000, lambda p: p.get("updated"), lambda p: (p.get("updated") or 0) * 1000)}


def listed(source, poll):
    d = poll["data"]
    return d if source == "discourse" else (d.get("data") or {}).get("proposals") if isinstance(d, dict) else None


def quantiles(xs):
    xs = sorted(xs)
    return {"n": len(xs), "min": xs[0], "p50": xs[len(xs) // 2], "p90": xs[int(0.9 * (len(xs) - 1))], "max": xs[-1]} if xs else {"n": 0}


def analyze(live_dir, source="discourse"):
    created, revision, updated = FIELDS[source]
    seen, versions, first_poll, last_poll, gaps, items, edits, offsets = set(), {}, {}, {}, [], [], [], []
    for poll in polls(live_dir):
        if poll["source"] == "clock" and isinstance(poll["data"].get("offset_ms"), float):
            offsets.append(abs(poll["data"]["offset_ms"]))
        posts = listed(source, poll) if poll["source"] == source else None
        if not isinstance(posts, list):
            continue
        key = poll["key"]
        if key in last_poll:
            gaps.append(poll["recv"] - last_poll[key])
        last_poll[key] = poll["recv"]
        initial = key not in first_poll
        first_poll.setdefault(key, poll["recv"])
        for post in posts:
            item = (key, post["id"])
            if item not in seen:
                seen.add(item)
                versions[item] = revision(post)
                if not initial:
                    items.append(poll["recv"] - created(post))
            elif revision(post) != versions[item]:
                versions[item] = revision(post)
                edits.append(poll["recv"] - updated(post))
    return {
        "source": source, "keys": sorted(first_poll),
        "window": [min(first_poll.values()), max(last_poll.values())] if first_poll else None,
        "hours_recorded": round((max(last_poll.values()) - min(first_poll.values())) / HOUR, 1) if first_poll else 0,
        "poll_gaps_s": quantiles([g / 1000 for g in gaps]) | {"over_10_min": sum(g > 600_000 for g in gaps)},
        "new_items_claimed_lag_ms": quantiles(items), "edits_claimed_lag_ms": quantiles(edits),
        "claimed_rule_failures": {"items": sum(l > RULE_MS for l in items), "edits": sum(l > RULE_MS for l in edits)} if source == "discourse" else None,
        "operative_rule": f"knownAt = first observation + {SOURCES[source]['margin']} ms",
        "operative_slack_ms": SOURCES[source]["margin"],
        "clock_offset_ms": {"max_abs": max(offsets), "n": len(offsets)} if offsets else None,
    }


def reconcile(data_root, live_dir, version):
    """Re-backfill (store version `version`) against what the recorder saw live, over the live window."""
    import polars as pl

    from ingest.store import Store, live

    seen, first_poll = {}, {}
    for poll in polls(live_dir):
        if poll["source"] != "discourse" or poll["recv"] > version or not isinstance(poll["data"], list):
            continue
        first_poll.setdefault(poll["key"], poll["recv"])
        for p in poll["data"]:
            seen.setdefault((poll["key"], p["id"]), (poll["recv"], p["cooked_sha256"], ms(p["created_at"])))
    raw = Store(Path(data_root) / "sources", key=["forum", "upstream_id"]).revisions("discourse")
    latest = raw.filter(pl.col("fetchedAt") <= version).sort("fetchedAt").group_by(["forum", "upstream_id"]).last().filter(live(raw))
    backfill = {(r["forum"], r["upstream_id"]): (r["eventTime"], r["content_sha256"]) for r in latest.iter_rows(named=True)}
    window_end = max(t for t, _, _ in seen.values()) if seen else 0
    missing = [k for k in seen if k not in backfill and seen[k][2] >= first_poll[k[0]]]
    changed = [k for k in seen if k in backfill and backfill[k][1] != seen[k][1]]
    backdated = [k for k, (created, _) in backfill.items()
                 if k[0] in first_poll and first_poll[k[0]] <= created <= window_end - RULE_MS
                 and (k not in seen or seen[k][0] > created + RULE_MS)]
    return {"live_items": len(seen), "deleted": len(missing), "edited": len(changed), "backdated": len(backdated),
            "backdated_examples": backdated[:10]}

