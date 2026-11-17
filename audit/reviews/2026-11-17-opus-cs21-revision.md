# Opus 5.5 (max effort, fresh session on TAMU) on the drafted dated revision to study 2's criteria

Session `859238c1`, given the same materials as GPT and the brief `data/builder/review-cs21-revision.txt`, without the advisor's view. Its review, verbatim:

# Review: the dated revision beneath "The days run" (study 2)

A fresh Claude Opus 5.5 session, 2026-11-17.
- **Read:** the six files in `cs21-rev/`; architecture 6.1 and 6.6 to 6.8, brief 3's recorders table and `recorder/VAULT.md` at `rearchitecture` `3f911d1`; `CLUSTER.md`.
- **Not read:** anything under `data/`, or the other reviewer's reply.

**In short.** Reading a day once, within the first cut that reaches it, is the right repair: it makes a rule of what the committed text assumed, and ends the repeated look a changing record gave every monthly replay. But one sentence sets the last midnight by the clock alone, so replays run past a stopped record. That can name a false "earned", and judges CS2.2 where the committed text says "not judged". The fix is one sentence; three other points are wording.

## 1. The last midnight no longer depends on the record (Q1, Q2, Q3). Fixable in the text; required

"The last midnight the record reaches is the last midnight 31 days or more before the replay starts" makes the committed term a function of the clock. Past the recorder's last line the engine still completes days. Every coin is stale (A3), so nothing fills and prices hold, and nothing aborts unless a held coin's settlement is missing (A18). Those days are run, cut, and stand.

- **CS2.2 judged on padding.**
  - Say the freeze is 2026-12-15, and the prodesk7 disk fills about 2027-05-20 (day 156). The human deferred that choice, and `vault` writes to `ws` too (`CLUSTER.md`). The account is flat then, so no settlement is due.
  - The replay of 2027-09-01 reaches day 212. Days 157 to 212 return exactly zero, so the forward variance is about 156/212 of the recorded days' variance.
  - A true ratio of 2.6 is judged 1.9, "held"; a true 0.6 is judged 0.44, "did not hold".
  - The committed text runs only to the last midnight the record reaches, so it gives "not judged". The revision falsifies CS2.2's own sentence that stopping "cannot make 'held'".
- **A false "earned".**
  - The recorder alone stops (say the websocket's format changes under it), while the REST collectors keep writing.
  - The ledger is at `Wᵇ` = 18.5, nearly all in one coin whose funding stays negative.
  - At a frozen price it collects carry with no price risk. At −0.001% an hour it passes 20 in about 340 days, with 574 left. That is "earned", where the committed text leaves 18.5, "not confirmed".
  - Past the stop, rung 1's null is false by construction. A no-skill ledger needs only reach 18.5, with chance up to 1/18.5.
- **Implementers will split.** It contradicts CS2.1's "a full disk ends the test early", architecture 6.8's "never run on over a gap", and brief 4, step 7's test 6 and foreseeable wall.

**Text:** "A replay runs to the earlier of two midnights: the last at or before the last quote its cut holds, and the last 31 days or more before it starts." This keeps the committed term and adds only the lag. Quotes, because they define staleness and listings can outlive the books. A gap that later ends is still staleness.

## 2. The writers' sentence is asserted, and is not yet true (Q2, Q4). Fixable in the text

"Each forward writer writes about a day only within the 30 days after it … so … when a replay starts changes nothing" is not yet so:
- `mmvault` pulls from its watermark less an hour and re-reads 30 days behind it (`VAULT.md`), so after an outage it writes days older than 30.
- The settled-funding collector is still owed.
- A suspended recorder, a clock that stepped, or a late copy each put a day's items past the first cut.

Then the time of the first attempt decides what the day holds. That lever reaches only anomalous items, and the committed text gave it at every replay, so it adds no false discovery. But a criterion should not assert what is false.

**Text:** "On a record whose writers keep to it, a day is whole before any replay reads it. Where one did not, the day is what the first cut holds, in every replay, and the report counts what was read or left with a writer's stamp more than 30 days after its day."

## 3. Which attempts bind, and over which files (Q1, Q4). Fixable in the text

- **"The first attempt of a replay whose horizon reaches a day"** reads two ways: the first attempt of each replay, or the first of all. It does not say whether a killed attempt binds (if not, killing one lets the day be cut again later), or which ledger counts. Wall 3 (`7f30189`) answers these; the criteria do not.
- **"Every file of the record"** names no writer and no host.
  - Brief test 10 needs files past the horizon: a print stamped 5 ms before midnight lies in the next hour's file.
  - If the vault's replay ran first one month and cut only `mmvault`'s files, the forward run would read that day with no recorder items, all stale.
  - A gap backfilled by a program that is no registered writer (prints rebuilt from the S3 archive, say) would be a record the operator chose after seeing the result.
- **"The hash of those bytes"** should be one hash per file, so a broken file can be named. What a broken file does to the verdict should be fixed too: wall 3 sends it to the architect, which is discretion.

**Text:** "An attempt is one in the study's evaluation ledger (kernel A13), a killed one included; it reaches a day when its horizon ends at or after the day's end. Before anything of the record is read, its row holds the length and hash of each file the registered writers had written, past the horizon included: the recorder, the settled-funding collector, `mmvault`, and the copy of the vault's fills before 2026-11-01. One cut serves every run over its days. An item is of the day of its own time. The keys and the record's order are wall 3's at `rearchitecture` `7f30189`. A file whose bytes in a cut no longer hash to it ends the test at the last day published, unless restored to those bytes."

## 4. "First replay after" belongs in the revision (Q3). Fixable in the text

"The first replay after the Nth judged day is run" has two readings: the first replay after that day ends, or the first whose horizon reaches it. Without the lag they coincided; with it they differ. Under the first, the next monthly replay has fewer than 212 days run, so CS2.2, judged once, is "not judged" for good.

The draft settles this in a bullet outside the quoted block, which would not be committed. Move it in. With the cut nothing else changes: every replay from the one that first ran day N gives the same verdict. The lag also helps CS2.3, whose judging no longer misses fills indexed a few days late.

## 5. Notes

- **First of a key reads a corrected error.** A held hour's rate first served at the 4% cap and corrected the same day, both inside the first cut, ends a ledger fully in that coin with under 4% in cash. "Last within the cut" is as stable and would not. Both are fixed blind, so size moves only if first values lean one way, which the revision count shows. State why "first".
- **Read once is final, even after an honest mistake.** A lagging copy at the first cut can end the test at a missing settlement, or leave an hour stale for good, where the committed text would read the full record a month later. Worth the price; name it among CS2.1's failures while the claim holds.
- **"By L1."** L1 assumes "one header but for the horizon's end", but a later header can carry a fee tier dated after an earlier horizon. A8 and wall 3's row check cover this; the kernel's wording should change.
- **"Starts" by which clock.** An attempt stamped by a host clock that stepped forward reaches a day before its writers finish.

## Q1 apart from §1

I found no lever the revision adds:
- More attempts read the same bytes.
- Backfilling a missing settlement or not, after peeking, is stopping versus continuing, and stopping only removes discoveries.
- Timing the first attempt matters only for anomalous late items.

Each is narrower than under the committed text, where every replay could read a changed record and "outgrew" was final at the first to name it. No threshold, judged day or engine rule moves.

## Verdict

**Commit with named text changes.** §1 is required: without it the revision adds false verdicts. Make §2, §3 and §4 as well. With all four, I find no way the revision adds a false discovery. The notes are optional.
