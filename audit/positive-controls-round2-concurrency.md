# Positive-control round-two builder checkpoint: concurrent writer

This builder paused rather than overwrite another writer's unfinished work in the same worktree. The initial worktree was clean. After its own `3c1ab87` checkpoint, `docs/whitepaper.tex` contained a different round-two rewrite and `audit/decisions.md` contained another builder's entry at 2026-11-09 04:30:08 UTC (2026-11-08 23:30:08 EST). Neither was written, discarded, staged or committed by this builder. Two attempted paper patches failed their context checks; no successful paper edit or PDF build was performed here. The question tool cannot obtain clarification in this non-interactive run.

The checkpoint's PROGRESS change includes both this builder's blocker and a separate paper-correction blocker added concurrently before staging, noticed only in the final diff. That other blocker is retained, not claimed as this builder's work; no attempt is made to erase it or rewrite the commit.

## Safe completed work

- Read CLAUDE.md/PROGRESS, main's Opus review and newest decisions, and the relevant committed sources/audit evidence. No `data/` was read or created, and no campaign, model, cluster operation, push or frozen-criteria edit was performed.
- Recorded the prior paper's design errors under Blockers before attempting replacement.
- Added `audit/positive-controls-round2-design-check.py.txt`: distribution/usage arithmetic only, no market imports or evaluation. Run with `nix develop -c python audit/positive-controls-round2-design-check.py.txt` from this worktree.
- Targeted checks: `ops/test_progress.py` and `ops/test_commitcheck.py`, 3 passed. An initial status-cap failure was fixed by shortening the new blocker before the checkpoint.

## Arithmetic for the finishing builder, not a frozen design

- If the operational distinction is rare recovery (probability at most .2) versus routine recovery (.5), the smallest fixed cohort with one-sided size at most .025 and power at least .95 is **33 agent markets**, rejecting rare recovery at **12 successes**. Actual size .02159; power .95993 at .5. Two endpoints (discovery and selected recovery) can use Bonferroni .025 each; this is not proof the rate exceeds .5 or a requirement to pass the study.
- The smallest model-free sample with every pointwise 95% Clopper–Pearson interval half-total-width at most .05 is **402** (401 misses). These choices are a defensible alternative to the other writer's 16/116, not permission to overwrite its design.
- At 33 sessions, empirical null-stop expectation is **$43.63 API-equivalent**, 2.838 five-hour equivalents, approximately **23–26 weekly percentage points** using the review's .081–.091 weekly/five-hour ratio. Review/build/probe use is additional. These are not cash invoices.
- Fits to the 20 committed stage-3 v3 sessions give five-hour use exponent **1.8012**, equivalent-dollar exponent **1.8527**. Recorded maximum is **135 turns**. At 200 turns, log-log / through-origin-quadratic projections are **.5798 / .6587 five-hour equivalents** and **$9.21 / $10.58 equivalent per session**. A .65 reservation does not exceed the latter usage projection; .75 does, but remains a planning choice, never a guaranteed upper bound. For 33 full sessions those fits project approximately **155–198 weekly points** and **$304–349 equivalent**; a .75 reservation totals **225.2 weekly points** before overhead. Hard research wall envelope: **66 model-hours**, not a quota guarantee.
- For that alternative paired design, the script's conservative distinct-program bound is 43,501, truth replays 1,740,040, two-sided/two-quantity Bonferroni critical value 8.2046 at df 19. Stream by market; do not regenerate per candidate. These bounds would need alignment with the finishing builder's actual manifest/reference family.

## Outstanding

No completed redesign, revised criteria, rebuilt PDF, finding-by-finding resolution or independent design review is claimed by this builder. Reconcile writer ownership before continuing those edits; keep `audit/criteria.md` untouched until a separately authorized criteria-only freeze. The human's unlimited study budget remains conditional on **TAMU/Cornell only, never personal**.
