# Last review of study 2's criteria (CS2.1 to CS2.3)

The advisor (Claude Opus 5.5), 2026-11-16 01:37 UTC (20:37 EST), before `criteria: study 2`. Read: `audit/program/criteria-notes.md`, section "Study 2", at `rearchitecture` `e691341`, in full; the reviews it answers (GPT and Argon round 1, the confirming read, GPT's check of fixes `2026-11-16-gpt-study2-criteria-r3-fixes.md`); the human's three decisions of 2026-11-15 (`audit/decisions.md`).

**Verdict: commit as drafted.** Argon (confirming read) and GPT (check of fixes) both say ready to commit; no dispute is open.

- **Each condition names its claim's outcome and when it is judged:** CS2.1 at each day's end of the days run, final at "outgrew" or day 730; CS2.2 once, after day 212; CS2.3 once, after day 61. Every window is fixed by the freeze, not chosen later.
- **Every number has its derivation or is called a choice:** 20 (Ville, K3, `Wᵇ ≤ W`); 2.39 (`20^(212/730)`); 24/25 (the 4% funding cap); the delays (the recorder's design cadence, no record); `√2`, 6 minutes and "more than half" are named tolerances; 61 and 212 are the held-back and replay lengths.
- **The human's decisions are in the text:** the bid valuation in CS2.1's two comparisons only; CS2.2 on `W`; the Holdout rule unchanged, with the freeze barred from the vault's fills and public record from 2026-11-01 on (architecture 6.5, brief 4 step 6).
- **Each lists runs that pass while the claim is false and fail while it holds,** including the reviewers' constructions (Argon's A at the bid, GPT's R4 at prices, a late-indexed round trip under CS2.3).
- **Noted, not blocking:** GPT's point that permitted integrity knowledge can move the freeze by a day and so shift the judged windows; the windows are still fixed before their outcomes, and the rule is the human's.
- **For the commit:** the conditions cite `architecture.md` section 6, `briefs/4-study-2.md`, `kernel-v2.md`, `KERNEL.md` and `arithmetic.py.txt`, which are on `rearchitecture`; the commit names `e691341`, as study 1's named `ce7ff38`.
