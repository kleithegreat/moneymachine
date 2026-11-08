# Review of `mirror-vanish` (9b88e80), fresh Claude Sonnet, 2026-11-07

Three-dot diff against main, run in a clean worktree; GPT built the change. Verdict: deploy. No finding loses or corrupts a recording, advances a manifest wrongly or silences a real alarm.

## Findings

1. Low. `ops/live.py:294-318`: a plain or workspace file replaced or rewritten shorter during its copy still fails the whole run ("the copy differs from its source"); reproduced by rewriting a `work/` file to 10 bytes inside `copy2` (probe P1). Not corruption: the tmp copy is discarded and the manifest not advanced, so a loud, retriable alarm 10 minutes later; the old code failed the same way. Same churn class as the reported crash, and agents rewrite workspace notes, so it may recur. An append during the copy is handled (P2). Changes a run's pass/fail, never a recording. Suggestion (a hypothesis): a plain file whose size or mtime changed since the pre-copy stat is omitted, not raised.
2. Low. `ops/live.py:303`: a manifested plain file that vanishes is dropped from the new manifest, including `raw/` bodies (plain by the writer contract); the old code crashed here but already tolerated the same deletion between runs, so the contract is unchanged and matches CLUSTER.md §5. The stale mirror copy stays on disk unlisted; readers trust only the manifest.
3. Test weakness, Low. `ops/test_live_churn.py:43-100`: for `work/nested/notes.jsonl` the `stat` phase passes on the old code (the hook fires at `is_file` or enumeration); `copy` and `comparison` fail on the old code, and the `stat` phase is covered by the other two paths.
4. Info. A ledger vanishing between stat and connect raises `sqlite3.OperationalError`, not the clean `SystemExit` (P8); it still alarms and leaves only an unlisted tmp file.

## Checked and fine

Reappearance after an omitted copy (P3); a vanished recording directory refuses the run (P4); a vanished manifested ledger is refused (P7); a day file vanishing after stat raises and publishes nothing (P5); plain copies are compared before replacing the target (the old code replaced first); the day append path is unchanged; a missing source with a manifested recording reaches the `gone` alarm; `mirror_source` swallows only a `FileNotFoundError` on the source or its parents; `verify` routes day sources through `mirror_source`; the writer-contract classification is unchanged.

## Tests

The new tests on the old code (`main:ops` copied to /tmp): 19 of 46 fail, 27 are guards passing on both. On the branch: `ops/test_live_churn.py` 46 passed; all of `ops` 331 passed; the full suite under `pytest -n 12` showed no failures up to about 96%, then an xdist teardown error hid the summary.
