# Fresh Opus on the Python-extinction plan, revision 2

Reviewer: a fresh Claude Opus 5.5 subagent at maximum effort, which did not architect the plan (a fresh Opus did); the plan's second review (Neon reviewed revision 1), from a different model only in session, so labeled as a fresh Opus's. Received 2026-11-24 17:26 UTC. Verbatim below.

# Review: Python's extinction, revision 2 (`a524c1c`)

A fresh Claude Opus 5.5 at maximum effort, who did not write the plan. 2026-11-24, 17:21 UTC (12:21 EST). Read-only in `mm-python-plan`; names and sizes only in `data/` and `/srv`. Read beyond the brief's three documents: every survivor and its tests, the flake, `ops/units.nix`, `CLUSTER.md`, the deployed user unit, the dotfiles' lock (names), `rearchitecture-s2`'s `RECORDER.md` and ledger, `main`'s decisions. Two offline experiments under `~/.cache/mm-python-review/`: `httpx`'s URL re-encoding (five feeds changed, as the plan says) and polars' sort (kept equal times in file order over 2M rows). No live command and no suite run.

**Verdict: revise before steps 3 and 5** (F1 and F2 are the design's; F3 is the acceptance's). Steps 0 to 2 can start now; 3a's guard section waits for F1, 5a and 5e for F3 to F7.

## Findings

**F1 (plan, design). Merging into `main` does not deploy the guard, and reverting does not roll it back.** 2.5, 2.7, 3e, 3f, 3g, step 4 and section 6 assume it does. The timer runs a store path: the `diskguard` app of the flake revision the dotfiles' lock pins (the lock now names `60b4ec9`), whose script is `exec python ops/diskguard.py`. Only the Python file is live from the checkout; an app holding `mmops` and a table from `ops/workloads.nix` is that revision's binary and table, until the human updates the dotfiles and switches.
- *Example:* 3e merges the guard and switches the mirror, which stops refreshing `hl`, `thesis`, `agent`. The timer still runs the Python guard of five volumes: hourly alarms on three. 3f deletes `ops/diskguard.py`; the pinned script's `python` finds no file, exits before notifying, and the unit has no `OnFailure=`. The proof, `nix run .#diskguard -- --test-alarm`, tests the checkout's build, not the timer's.
- *Outcome:* the recordings' only capacity alarm silent; a full disk costs recordings (`ws`: 2.0 GB a day, one copy).
- *Fix:* the app resolves the checkout at run time (`nix run .#mmops -- diskguard`), which makes section 6 true, with `OnFailure=` notifying a run that cannot start; or the dotfiles update is a named step before 3f and its lock the rollback. Simplest for the second reader: `mmops mirror` writes the volume list it covers, with `taken`, and the guard expects that, deleting 2.5's order rule.

**F2 (plan, design). The way back from a cluster switch is incomplete and untested.** Section 6: "a cluster workload rolls back by applying the previous image digest". After step 1 the manifests (command, mounts) are the flake's, and 3e and 5e change them. The old digest under the new manifest starts `mmops` in an image without it. The old command alone meets mounts without `hl`; an absent source reads as an empty one, so `hl` refuses ("recording files vanished") and the run, whose first volume it is, never copies `sources` or `datalayer`.
- Rolled back for real, the Python rewrites every manifest (`taken`, `capacity`) each run, so "changes nothing" is false and the pins fail on roll-forward.
- *Outcome:* the live data's only copy stops while prodesk7 alone holds what is newer.
- *Fix:* the way back is the previous revision's `apply` at the previous digest, shown by `kubectl diff` to be the running spec before each switch (1b's check, per switch). Pin the file list (path, size, sha256), not the manifest's bytes.

**F3 (plan). Status parity passes a body that is no data, and a feed never polled.** Neon's finding 2 is half closed: the requests (5d) are compared, but a request problem can come in a reply whose JSON reads `REQUEST_SUCCEEDED` (BLS's API FAQ, an invalid series), so a status equal to the Python's does not establish that keyed feeds' bodies are data, at the rehearsal or at the cut. And "for every feed polled in 48 hours" leaves out feeds `mmdata` never polls: if its key file's default is not the Secret's mount (`/app/repo/.keys.env`), nine keyed feeds (BLS five, BEA two, EIA one, SEC one) are held at start, named in a log no check reads, with no row to compare.
- *Outcome:* the point-in-time record of those feeds is error documents or nothing; a revised series cannot be refetched as of its dates.
- *Fix (5e, items 1 and 3):* every feed due in the window by the Python's log has an `mmdata` row; the start's no-key list is empty; status equal; and the body's `bytes` near the Python's last for that feed (a size, integrity data). Feeds slower than 48 h (578 of 642) meet the window only if due: rehearse in a Job on prodesk7 with the Secret and an `emptyDir`, the deployed image and mounts, keeping forward-window bodies off this PC.

**F4 (plan text: 5a, 5b). Two decisions since revision 2 are missing, and one is stale.**
- *GDELT.* The advisor's entry of 2026-11-23 03:26 UTC (22:26 EST) makes `mmdata`'s spec retry a named file until 200 or the next index, two fifths of exports being answered 404 once. 5a and 5b have no rule. D1's `every_h` of 1/12 asks a named file about three times while it is named, so the retry may be emergent, but the spec must state it and test it; the backfill of the missed files is owed beside it.
- *The clock rule.* 2.2 reuses D338, study 2's round 17. Since then: D351 deleted the reply's `Date`, D358 restored it under an hour's check, D361 (round 20) deletes the check and places a reply by its two clocks, every REST line keeping `date`. `DATALAYER.md` must cite that, drop "takes a time only where they agree", and keep `Age` beside `Date`: a cache's reply carries its origin's date, so it can agree with a host late by the cache's age (study 2 asks its reviewers to attack that case).
- *Outcome:* a later reading-agent study's known-at (a judged result).

**F5 (plan text: 5a). `recv`'s moment is unspecified.** The Python reads it after storing the body. A port stamping it at the head would date a body before it was known. `DATALAYER.md` must place it after the last byte. Outcome: as F4's.

**F6 (plan text: 4, 5a, 5d). Datalayer rollback.** "Escaping is free" (section 4), but the Python reader, the rollback's, opens day files as text and dies on a UTF-8 character cut by a kill (its own strict xfail): rows stay ASCII while the Python can return. 5d tests the store one way only: run the Python's `last_polls` and `body` over the store `mmdata` wrote, same due set. Outcome: a rollback that crash-loops, recordings stopped (low probability, cheap to close).

**F7 (plan: 2.2, 5a; deletions). Two items are larger than their cause.**
- *Connection reuse.* Row 4's cause is the pass, at least a second per due feed (435 weekly feeds together), which change 5 answers by order and bound; reuse is courtesy, and a handle kept across feeds carries state: a `User-Agent` credential a reset misses goes to the next feed's host (SEC's contact), which 5b's test 2, one request, cannot see. Delete it for the recorders' fresh handle per poll.
- *The body cap.* "18 times the largest seen" compares the 1 GiB cap on the decoded body with a gzip size: take the margin from the log's `bytes`. Also 240 s is a total where httpx's 120 s is per operation; the rehearsal measures it.

**F8 (text).** 5d test 2 cannot be "equal by value" in `sent`, `recv`, order or `date` across two schedulers that differ by design (change 5): compare by feed, those aside. 2.5's "list the same files" must be "hold the same entries". `ARCHIVE.md` says only "deduplicated on it": K1b's oracle needs which of equal times is kept (the first, in hour-then-line order).

## Neon's eight findings

1 closed: `free ≤ total / 5` equals `free × 5 ≤ total` on nonnegative integers. 2 half closed (F3). 3 closed by `Date`, with F4. 4 closed. 5 closed but for the rollout order (F1) and the pins on rollback (F2). 6 closed. 7 closed (K1b). 8: diff before deletion, the `List`, the tag closed; the rollback premise true of `push`, `apply` and the hooks, not of the guard (F1) or of the cluster's manifests (F2).

## The four disputed rows: my sides

- **Row 3 (the clock's instrument): the architect's, with F4.** The bound wanted is the host's lateness at each `recv`. `adjtimex` is the host's word about itself; `Date` is an independent clock in the row itself; and `ws`, on the same node, records a venue stamp beside `recv` on every frame, the same kernel clock. Retiring `sources` loses nothing; waiting for 5e costs nothing.
- **Row 4 (the cause): the architect's.** A pass costs a second per due feed, a handshake some 100 ms; change 5's order and bound settle the cadence. Reuse then goes (F7).
- **Row 5 (the rollout order): Neon's.** The derivation "removing is merged first" needs merge to be the guard's deploy. F1 shows that false for a Nix-built guard.
- **Row 7 (the fetcher's spec): the architect's.** A spec to build from is a live form, code with no run is not; a pull is the human's to approve, and git keeps the Python.

## Accepted

The language split; the ratchet; seal (SQLite and `work/` leave the port); the `mtime`/`statvfs` stub (`core_unix` 0.17.1 binds no `statvfs`); exact integers; the five rewritten URLs and the request differential over all 642; streamed bodies and the `len − 1` carry; change 5 and D1; `mmdata` as its own process; `ws`'s capacity manifest; K1b before step 6; `sources` after 5e under R1.

## Steps 0 to 2 can start now

Yes, with two conditions: between step 1 and 3f the volume list has two homes (the table for mounts; `diskguard.VOLUMES`, in the image, for the Python mirror), so a flake check must hold them equal; and the table stays the workloads' alone until F1 is settled, since the guard's reading belongs to 3e. Step 1c still waits for a deploy through the apps. None of F1 to F8 touches steps 0 and 2.

## Ledger

| # | Point | State | Changes what is built or run |
|---|---|---|---|
| F1 | Guard's deploy path, `OnFailure=`; row 5 | Disputed, plan | **Yes** (2.5, 2.7, 3e to 3g, 4, 6) |
| F2 | Way back: previous revision's manifest; pin the file list | Disputed, plan | **Yes** (6, 3e, 5e) |
| F3 | Acceptance by row, status and size; the rehearsal a Job | Disputed, plan | **Yes** (5e) |
| F4 | GDELT's retry; D361's clock; `Age` | Agreed need; spec | **Yes** (5a, 5b) |
| F5 | `recv` after the last byte | Spec | **Yes** (5a) |
| F6 | ASCII rows; the Python reads `mmdata`'s store | Spec, test | **Yes** (4, 5a, 5d) |
| F7 | Fresh handle; cap from `bytes` | Deletion, text | **Yes** (2.2, 5a) |
| F8 | 5d.2 by feed; seal and dedup wording | Text | Wording |
| Row 3 | `Date`, not `adjtimex` | Agreed with the architect | Text (F4) |
| Row 4 | The pass; reuse deleted | Agreed with the architect | **Yes** (F7) |
| Row 5 | Rollout order | Agreed with Neon, through F1 | **Yes** |
| Row 7 | Fetcher's spec stays | Agreed with the architect | No |
| Steps 0 to 2 | Start | Agreed | No |

**Disputes that change what is built or run:** F1, F2, F3 and row 5. The one that must not be left standing is F1's alarm gone silent at 3f; next, F2 before the first cluster switch at 3e.

Source: [BLS API FAQ](https://www.bls.gov/developers/api_faqs.htm).
