# Fresh Opus on round 15's study 2 half (D306 to D322)

A fresh Claude Opus 5.5 subagent at maximum effort, labeled as `CLAUDE.md`'s fallback for GPT, whose budget is reserved (the human, 2026-11-22); Neon read the round too (`2026-11-22-neon-round15-study2.md`). Worktree `rearchitecture-s2` at `2bf7ad4`; jsont probes on synthetic inputs under `~/.cache/mm-r15s2-review/`. Run 2026-11-22, across two usage stops. The review, verbatim:

# Fresh Opus on round 15's study 2 half (D306 to D322), the fallback for GPT

Claude Opus 5.5, maximum effort, fresh: the fallback for GPT, whose budget is reserved (the human,
2026-11-22); Neon reads beside it. 2026-11-22, 17:12 to 21:27 UTC (12:12 to 16:27 EST), with a usage-limit pause.
Worktree `/home/kevin/repos/mm-review-r15s2` at `2bf7ad4`. Read: the subject whole, both round 14 reviews, the
committed CS2.1 to CS2.3 and jsont 0.2.0's pinned source. Probes, synthetic only: `~/.cache/mm-r15s2-review/jsont/`
(`t.ml`, `probe-output.txt`). No market data, nothing under `data/holdout/`, no key file.

**In short.** The three deletions (the hold, the clamp, the framing check) are right, and the end at the reach, clause
0, the state chain, the decoder and the allocation survive construction. F1 and F2 change what is built; F3 to F5 are
smaller; the rest is text.

## Findings

**F1. A print the recorder cannot decode never reaches the reader's rule (design; CS2.1 to CS2.3).** D317 makes a
`trades` line that holds no item a gap in its coin's prints, naming lines "not JSON or not of the channel's shape". But
`RECORDER.md` routes "a frame those steps do not decode" to `events`, which no capture holds, and the steps decode "of
a frame its channel, its coin". Construction: from day 100 the venue's `trades` frames carry the coin under another
key, or wrap `data` in an object. Every such frame goes to `events` and the `trades` files fall silent; each coin's
subscription stays acknowledged, so its books go on to `l2Book-fast`; the reader meets no `trades` line, so no gap,
and feeds every book: each coin fresh and never filled on a print. That is Neon's construction 6.1 of round 14, moved
from the reader to the router; the new rule fires only on frames the recorder decodes that then fail A18's grammar
(`"1e-5"`). Fix in `RECORDER.md` before step 1's tests are written: a frame whose `channel` is `trades` goes to
`trades` whatever its data (its coin read, where it can be, only to acknowledge); a fast connection's frame that is not
JSON unpairs every coin of that connection until its next `trades` frame, which only the router orders exactly (round
13's own reason). Two text points: the rule is per line, so a frame of five prints with one unplaceable price withholds
nothing and loses that print (say "a line holding any print the reader cannot read"); and the architect's question 8
answers yes: one unreadable print on a quiet coin withholds its books for hours, until its next readable print (fills,
not size).

**F2. Ending at a stop is right; some stops are not stops (design; survival of CS2.1, of CS2.2 before day 212, of
CS2.3 before day 61).** D309's permanence holds (below). But brief 3's C2 rejects, beside contradictions between two
items (a second settlement of one hour, a trade id repeated with other content), events that fail on their own content
under the rules in force: a price off the grid, a price of zero, a number out of range. The reader already drops one
such class, crossed and one-sided quotes, "so none stops a run", and round 15 treats an unplaceable print the same way.
Drop the rest alike: counted, not fed, a print among them a gap in its coin's prints, so the coin is stale until its
events fit the rules in force, which the next copy restores. That reads each line against copies received before it,
the draft's own null, and needs no lookahead, where the union admission the architect weighed needed the later copy's
rules early. It deletes wall 2's cost (every lot-size change of a universe coin ends the test) and three ends the
design now accepts: a change between Day 1's copy and `w_start` ends the test on day 1; a host clock stepped back
across a change ends it (the round's own "Copies out of clock order" test); one zero-price print from a venue glitch
ends two years. Its price is at most a copy interval of staleness per change. The record gives no rate: the vault's
5,806 fills of seven months fit one copy's lots and grid, so changes are rare, not excluded, and each now ends the test.

**F3. A refused report ends the study for good (design and text; survival).** D312 and draft end (6) make
`halt_substitution` terminal; only a changed file's halt resumes. Brief 4 also says a replaced state chain "resumes
from the last accepted state", but Step 2 runs from the state on disk, so a stale chain (a volume restored after an
outage like today's) first yields a report from a state that is not the last accepted, which the check refuses, which
halts: everything unjudged becomes "not judged". The runner is a pure function: the month rerun from the accepted state
gives the one right report (that state rebuilt from `State_0` through the accepted captures, each link checked against
`accepted.tsv`, if its bytes are lost), and a rerun from an older state gives a byte-identical duplicate of an accepted
report or nothing anyone quotes. So a refused report names nothing and its month is rerun; delete
`halt_substitution`. Detection, the halt's purpose, is unchanged.

**F4. Nothing binds a report to its month's capture (design, small; CS2.3's judging, CS2.1's looks).** Acceptance
checks the four identifiers and the prior state; `Capture_k`'s hash is printed and recorded, never checked. A second
capture of a month (a Step 1 that lost the first's record, a manual one) passes, and since CS2.3 is judged at the first
capture holding coverage, a later capture can move its judging, by accident or by choice. GPT-6.2 asked for the link
"to the settled capture"; D311 records it without fixing its far end. Push each manifest's hash when Step 1 commits it,
and accept a report only on the capture pushed first after its firing: D311's own mechanism.

**F5. The collectors' clocks are trusted, never witnessed (premise; CS2.3's coverage, an end's finality).** Coverage
needs a pull "begun at least 31 days after `t`", finality one "begun at least 30 days after `e`", both by the file's
name, the collector's host clock; the recorder's clock got a witness rule and a 2030 test, the collectors' a day of
margin. Construction: prodesk7 boots 40 days ahead. That night's funding pull makes a coin flagged five days earlier
final at once; its last settlement, served late but inside the assumption's 30 days, then moves an end that a firing
had already published past: `T*`. That night's vault re-read covers instants up to nine days past its own making, so
CS2.3 can be judged on fills shown for minutes, not V18's month. An HTTP server states its own time in each reply
(`Date`, RFC 9110): if the venue's does, storing it in each line and timing pulls and listings copies by it would
remove the host clock where it is weakest. At least, state the premise and test a pull named in 2030.

## Text

- **Holes against the relisting test:** "a coin's hour with no settlement before its last one holds `T`" makes a
  relisted coin's gap a hole for good, where the test ends it at 10:00; clause 1 sides with the test. Say "before its
  last one and before its end".
- **Day 1's "omitted if delisted"** duplicates the end rule ("a reach at `w_start` ends the coin there") and reads the
  flag alone, so a flag withdrawn just before `w_start` drops the coin for two years. Delete it.
- **One run, two ends:** a run that diverges and fails the fee witness has two midnights, and which applies decides
  whether a non-final "Earned" stands. Say the earlier.
- **Depth:** the recorder bounds the frame or body at 64, the reader the line, a level deeper; probe: a frame of 64
  passes the recorder and its line of 65 fails the reader. No real reply nests so; bound the line at 65.
- **"Framing bytes ... cannot form part of one"** is false for an empty array: `[` and `]` around a chunk-size line
  `\r\n1\r\n` decode as `[1]` (probe). Every array read is shape-checked and skipped members are not read, so nothing
  moves; rest the argument on "no strict prefix of an array or object is a value".
- **CS2.3's draft** should say *distinct* fills, as `VAULT.md` does. Exactness also assumes retention keeps the latest
  10,000 by `time`, counting what this endpoint returns; a 31-day pull holds a tenth of that and the 5,000 alarm stays,
  so it moves nothing, but say it.
- **The 725:** `ingest/hl.py` holds from the sending, not to 60 s after the end, and one request can straddle a venue
  minute: its term is about 420, not 400, still far under 1,200.

## Confirmed

- **D309.** A stop in a run to `T_raw` stays: reaches and ends only move later, clause 1 excludes
  `R_SETTLEMENT_MISSING`, and a copy timed before an event cannot be written after the capture holding it, given the
  receipt-clock premise and no listings line written over about eleven hours after receipt (a capture comes twelve
  hours or more after its horizon). One qualification, from D317: a book fed in one run is withheld in a later one if a
  `trades` line before it is written late, so a stop on that book can vanish; only a late-written line, `T*`'s premise,
  does it. Ending costs survival, never size (Ville at any stopping).
- **D306, D307.** Neon's three constructions and GPT-6.2's 10:20 row end where the tests say; a flag read up to an hour
  off qualifies only a gap through `B(e)`; a coin flagged while still paid ends nothing until a later hourly flag
  qualifies the real gap; the open tail's empty page from the reach makes a true end final. No end falls before a held
  settlement within the premise.
- **D308.** Clause 0 binds only once every coin has ended, when the remaining days are all cash: harmless.
- **D311.** A rollback and a forged `State_4'` are refused.
- **D314, D315** (source and probes): `01`, `-nan`, `+1`, `1.`, a byte-order mark, lone surrogates, invalid UTF-8 and
  trailing text fail `Jsont.ignore`; a number's location gives exactly its bytes; a member named twice is decoded by
  type each time, the last kept; no cut array or object decodes. A builder trap: checking the bytes once on the kept
  value reads `{"time":null,"time":2}` as 2 (probe), which test 21 refuses; the check belongs in the field's decoder.
- **D316.** No livelock: a saturated pull covers every instant after its oldest fill, and re-reads start past what
  retention took.
- **D318.** The hold-to-end argument is correct and the allocation enforceable.
- D310, D312 but for F3, D313, D319, D320, D322; the reserve's draft as it stands.

## Ledger

| Status | Point | Changes what is built or run? |
|---|---|---|
| Agreed | D306 to D311, D313 to D316, D318 to D320, D322; D317 but prints; D321 but end (6) | As proposed |
| Disputed | F1: route by `channel`; unpair on a frame that is not JSON; per-print gaps | **Yes**: `RECORDER.md`, before step 1 |
| Disputed | F2: single-event rejections dropped and counted; stops kept for contradictions | **Yes**: the frozen reader (A18), wall 2 |
| Disputed | F3: a refused report rerun, `halt_substitution` deleted | **Yes**: step 6, D312, draft end (6) |
| Disputed | F4: each capture's hash pushed at its commit and checked | **Yes**: Step 1 and acceptance |
| Disputed | F5: the collectors' clock | **Yes** if `Date` is stored; else a premise and a test |
| Text | holes, Day 1, two ends, depth, the framing sentence, *distinct*, the 725 | No |

**Does any dispute change what is built or run?** Yes: F1 before the recorder's step 1 is tested; F2, F3 and the text
points before the reader and the runner freeze. None touches a committed criterion; F3 changes a draft.
