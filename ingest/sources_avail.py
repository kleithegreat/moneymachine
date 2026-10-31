"""C5.3's reported figures (stage 5 amendment of 2026-10-22: both sources are prospective, so these are reported,
not judged), per source over its whole live recording. A new item is one first observed in a poll after its key's
first poll; an edit is a later poll showing a changed revision. The operative rule makes an item known `margin` ms
after its first observation, so its slack is that margin by construction. The claimed time's lag (first observed
minus claimed creation or update) is reported for information; for Discourse, against the rejected 600 s rule.
Uptime is the share of the recording span outside gaps of more than GAP between successful polls. The drop
check counts polls whose list shares no item with the key's previous successful poll: items could have
passed between them unseen."""

from pathlib import Path

from ingest.events import GAP, SOURCES, polls
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
    seen, versions, first_poll, last_poll, gaps, items, edits, offsets, bounds = set(), {}, {}, {}, [], [], [], [], []
    failed, no_overlap, previous = 0, 0, {}
    for poll in polls(live_dir):
        if poll["source"] == "clock" and isinstance(poll["data"].get("offset_ms"), float):
            offsets.append(abs(poll["data"]["offset_ms"]))
        if poll["source"] == "clock" and "maxerror_ms" in poll["data"]:
            bounds.append(poll["data"])
        if poll["source"] != source:
            continue
        posts = listed(source, poll)
        if not isinstance(posts, list):
            failed += 1
            continue
        key = poll["key"]
        ids = {p["id"] for p in posts}
        no_overlap += key in previous and bool(previous[key]) and not ids & previous[key]
        previous[key] = ids
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
        "poll_gaps_s": quantiles([g / 1000 for g in gaps]) | {"over_10_min": sum(g > GAP for g in gaps)},
        "uptime_fraction": 1 - sum(g for g in gaps if g > GAP) / max(sum(gaps), 1),
        "failed_polls": failed, "polls_without_overlap": no_overlap,
        "new_items_claimed_lag_ms": quantiles(items), "edits_claimed_lag_ms": quantiles(edits),
        "claimed_rule_failures": {"items": sum(l > RULE_MS for l in items), "edits": sum(l > RULE_MS for l in edits)} if source == "discourse" else None,
        "operative_rule": f"knownAt = first observation + {SOURCES[source]['margin']} ms",
        "operative_slack_ms": SOURCES[source]["margin"],
        "clock_offset_ms": {"max_abs": max(offsets), "n": len(offsets)} if offsets else None,
        "clock_bound_ms": {"max_maxerror": max(b["maxerror_ms"] for b in bounds), "n": len(bounds),
                           "valid": all(not b["unsynced"] and b["maxerror_ms"] < 1000 for b in bounds)} if bounds else None,
    }


CONTENT = {"discourse": (lambda p: p["cooked_sha256"], "content_sha256"), "snapshot": (lambda p: p.get("updated"), "updated")}


def reconcile(data_root, live_dir, version, source="discourse"):
    """The re-backfill at store version `version` against what the recorder saw live up to it. Live items are
    every item listed in a poll up to `version`, over the window from the first such poll to the last; deleted,
    those created since their key's first poll that the backfill lacks; edited, those whose content differs; backdated, backfilled items claimed inside the live
    window but first seen live more than RULE_MS after their claim, or never."""
    import polars as pl

    from ingest.store import Store, live

    created, _, _ = FIELDS[source]
    live_content, stored_content = CONTENT[source]
    key = SOURCES[source]["key"]
    seen, first_poll, window_end = {}, {}, 0
    for poll in polls(live_dir):
        posts = listed(source, poll) if poll["source"] == source and poll["recv"] <= version else None
        if not isinstance(posts, list):
            continue
        first_poll.setdefault(poll["key"], poll["recv"])
        window_end = poll["recv"]
        for p in posts:
            seen.setdefault((poll["key"], p["id"]), (poll["recv"], live_content(p), created(p)))
    raw = Store(Path(data_root) / "sources", key=[key, "upstream_id"]).revisions(source)
    latest = raw.filter(pl.col("fetchedAt") <= version).sort("fetchedAt").group_by([key, "upstream_id"]).last().filter(live(raw))
    backfill = {(r[key], r["upstream_id"]): (r["eventTime"], r[stored_content]) for r in latest.iter_rows(named=True)}
    missing = [k for k in seen if k not in backfill and seen[k][2] >= first_poll[k[0]]]
    changed = [k for k in seen if k in backfill and backfill[k][1] != seen[k][1]]
    backdated = [k for k, (claimed, _) in backfill.items()
                 if k[0] in first_poll and first_poll[k[0]] <= claimed <= window_end - RULE_MS
                 and (k not in seen or seen[k][0] > claimed + RULE_MS)]
    return {"source": source, "version": version, "window": [min(first_poll.values(), default=None), window_end],
            "live_items": len(seen), "deleted": len(missing), "edited": len(changed), "backdated": len(backdated),
            "backdated_examples": backdated[:10]}
