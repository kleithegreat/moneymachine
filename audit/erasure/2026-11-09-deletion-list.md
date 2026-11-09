# Repo-wide deletion list

**Reviewer:** Claude Opus 5.5 (fresh context, erasure reviewer; did not build the code swept)
**Written:** 2026-11-09 06:52 UTC (01:52 EST; EST = UTC−5), sweep started 06:40 UTC (01:40 EST)
**Commit swept:** `a53c0a051a5178e3f2b887e84150d442e2a4c153` (main). Read-only looks at `stage7` (`30db80e`), `thesis-refreeze` (`6dc18a3`), `positive-controls` (`9e4da60`), `code-style` (`8944c11`).
**Read first:** CLAUDE.md §2–3; `audit/erasure/` (the stage 3 pass and GPT's list); `audit/decisions.md:303` (2026-10-28, erasure is blocker-class) and `:765` (2026-11-08, the human on the meta review); `audit/reviews/2026-11-08-gpt-meta-review.md`.
**Not read:** `data/holdout`, forward-window data, any price or return.

## Method

- Python dead code: an AST scan of every tracked module's top-level functions, classes and assignments, counting each name's occurrences over all tracked text outside `audit/` and `docs/research/`. Then the same scan, keeping only names whose other references are all in tests. Then a module scan: modules imported or run by at most one other file.
- Rust: every `fn` in `kernel/mm/src` and `reference/mmdump`, with references counted over the Rust sources and the mutants. Lean: every `Ref/**` module checked for an importer.
- Tests: test functions with no assertion, `raises` or `xfail`; file names tied to a criterion, round or version.
- Mechanisms: each `cli.py` command, `ops/` script, workload, flake package and dev shell checked for a caller, a doc that names it, and the decision that ended it.
- Prose: CLAUDE.md, PROGRESS.md, CLUSTER.md, `docs/future-work.md`, the paper's process and roadmap lines, and the specs, compared with one another and with the decisions log.

The codebase's top level is already clean. The AST scan found one unreferenced name (`ingest/policy.py:11`) and no production function used only by tests apart from fixtures (`gate/markets.py:write_market`, which the positive-control design reuses, and `ops/runaway.py`, a test target). Rust has no dead functions. Every Lean module is imported, and every image under `docs/research/*/media` is referenced. What remains to remove is whole mechanisms, parallel paths that a swap left behind, and stale prose.

## Totals

| Category | Items | Lines (approx.) | Of which waits on a call |
|---|---|---|---|
| Tracked artifacts no longer needed | 1 | 2,338 | 0 |
| Dead or finished mechanisms (code, tests, flake, config) | 4 | 1,145 | 780 (agent-real, human/advisor) |
| Parallel paths and duplicated helpers | 5 | 105 | 45 (`cli check`, advisor) |
| Stale or duplicated prose | 6 | 50 | 3 (CLAUDE.md and the BigQuery survey, human) |
| Branches (after their freeze or landing) | 1 | ~1,300 to fold, net unknown | 0 |
| At the next fork (frozen identities) | 4 | ~15 plus DSL.md prose | n/a |
| Outside the repo (advisor's memory) | 1 | 2 files | 0 |
| **Removable now, without a call** | **14** | **≈2,860** | |

All figures are line counts from `wc -l` or AST spans, rounded. Line references are to the swept commit.

## Ranked list: removable now

Ranked by lines and concepts removed per unit of risk.

### 1. `ops/homelab/`: Nix installer receipts and step logs (4 files, 2,338 lines)

- **What:** `ops/homelab/receipt-153.json`, `receipt-222.json` (1,156 lines each), `install-153.log`, `install-222.log` (13 each). The Determinate installer output from gmktec and prodesk7, 2026-10-26.
- **Evidence:** commit `dad029d` kept them "for verifying cleanup". The cleanup is done and checked: `audit/decisions.md:249–251` (2026-10-28 06:07 UTC (02:07 EDT)) records the uninstall on both hosts "by its own uninstaller, then checked: no `/nix`, no Nix units, no build users, no shell hooks". The only pointer to them was the PROGRESS cleanup list, which `2bb8f7c` removed. `git grep -n "ops/homelab\|receipt-1\|receipt-2\|install-1\|install-2" -- ':!ops/homelab' ':!audit'` finds nothing. They are not under `audit/`. What they recorded is now in decisions.md, and git keeps the bytes.
- **Risk:** none. No code or test reads them. Today's Nix on the nodes is a different installation (CLUSTER.md §7: prodesk7's lives in `/var/lib/mmtest`).
- **Call:** a builder decides and logs one line.

### 2. `ingest/archive.py` and its test, plus the `cloud` shell's AWS and BigQuery tools and `lz4` (≈355 lines)

- **What:** `ingest/archive.py` (262 lines), `ingest/tests/test_archive.py` (88 lines). In `flake.nix`: `lz4` in `pythonFor` (line 30), and the `cloud` shell's `awscli2`, `google-cloud-sdk`, `lz4`, `boto3`, `google-cloud-bigquery`, `numpy` and `polars` (lines 71–76), which leaves `oci-cli` for `ops/oci`.
- **Evidence:** no caller. No `cli.py` command, and `git grep -n "ingest.archive\|from ingest import archive"` finds only its own docstring and its test. Its two jobs ended. The archive equivalence check failed and the pre-holdout cost-table alternative lapsed (paper :535; `audit/stage3/archive-equivalence.json` records the outcome). The regime diagnostic "decides nothing" (its docstring; human-approved 2026-10-26 as such). The 2026-10-28 decision (`audit/decisions.md:303`) folds in "deletion of one-off scripts whose outputs are recorded". `boto3` and the AWS CLI serve only this module (`git grep -l boto3` gives `ingest/archive.py`). `lz4` serves only this module and its test. BigQuery: nothing in code uses it. `venue/sources.toml:648` `bigquery-crypto` has no terms record ("no automated research use until a terms record is added").
- **Risk:** low. Reproducing the archive diagnostic at HEAD would need git history. No judged result depends on rerunning it. `test_archive.py` goes with the module. Data already fetched under `data/` stays.
- **Call:** a builder can remove the module, its test and the AWS and `lz4` packages, logging one line. The BigQuery half is item 17 (the human set up that account).

### 3. CLUSTER.md: the move's history and the finished campaigns' runbook (≈36 lines)

- `CLUSTER.md:4–5` ("Batch Jobs stay as they are") and `:8–11` ("now inside runner pods … stage 3's harness is refrozen before its first campaign, and stage 10 cuts a new track version at the move") narrate the move of 2026-10-30. §6 (`:217–221`) already says it is done and points to `audit/cluster/handoff.md`. Either keep §6's pointer and delete `:8–11`, or the reverse: about 5 lines.
- `:87` "and `data/thesis` and `data/universe.json` at the move", `:141` "as the copied credential file was before", "(as today)" at `:68` and "as today" at `:184`: phrases that only make sense relative to the move. About 2 lines.
- `:144` "**Gate before cut-over**": the list is still the contract of `ops/live.py gate`. Rename it to "Gate", and fold `:133–134` (§3's one-line "Gate") into it. About 2 lines.
- `:199` "It no longer edits `PROGRESS.md`.": describes a past change (commit `49db90a`). 1 line.
- `:207–208`: the mirror CronJobs' deployed digest, its predecessor and the rollback. This is status, and PROGRESS:13 repeats it. PROGRESS is status's home, so keep the rollback rule ("re-apply the previous digest to those two") and drop the dated deployment line. 2 lines.
- `:55` (the `agent-real` row), `:104–123` (`agent-real`'s seeding and resume runbook, `agent-summary`'s stage 3 instructions), and in `:49` and `:94–97` the phrases "now stage 4's C4.5" and "stage 3's `agent` cohort is done". Stage 3 exited 2026-11-01 (`audit/stage3/exit.md`), and its window was claimed in this PC's `data/holdout/spent.jsonl` before `apply` (the runbook's own `:111`), so it can never run again. C4.5 v3 finished (PROGRESS:13). About 24 lines. This prose can go now even if the code in item 14 stays: the code's tests document it.
- **Risk:** none. CLUSTER.md is prose, and the handoff record is `audit/cluster/handoff.md`.

### 4. The Oracle pull's PROGRESS-editing alarm: a parallel alarm channel the diskguard swap left behind (net ≈ −25 lines, one mechanism)

- **What:** `ops/oci/pull.sh:2–3, 13, 25, 30–33` edits PROGRESS.md's Blockers with `sed` and `awk` on failure, and clears the line on recovery. `ops/test_oci_pull.py` builds a PROGRESS fixture (`:43`) and asserts on it in four tests (`:79, :94, :141, :163`).
- **Evidence:** commit `49db90a` (2026-11-06) replaced the same mechanism in the disk guard (`-# … add one line under PROGRESS.md's Blockers`, with the identical `awk` line) with `notify-send` plus a journal log. CLUSTER.md:199 records that. The pull kept the old channel. A timer that writes PROGRESS.md also dirties the main checkout unattended, and those edits race against builders' commits.
- **Proposal:** `pull.sh` only exits nonzero with its message. `ops/diskguard.py`, which already alarms on reports older than 30 minutes, adds one check: `data/live-oci/last-pull` older than its bound. One alarm path, one test file (`test_diskguard.py`) for staleness, and the pull tests assert the exit status.
- **Risk:** moderate. The VM holds the only copy of forward-window Hyperliquid days, so the alarm must not go silent. Do it as a defect-first change: a failing test that a stale `last-pull` alarms, then the change, then the four pull tests rewritten to assert exit status. It touches no recording (the pull never deletes) and no frozen identity.
- **Call:** a builder decides, since it is reversible. It is not an independent-review boundary, but the failure-path tests are required.

### 5. `cli check` beside `ops/shards.py`: two suite runners, and cargo tests and mutants run by neither in practice (≈45 lines; also fixes a coverage hole)

- **What:** `cli.py:16–60` (`PYTEST_BYTES`, `CARGO_BYTES`, `check()`, `mutants_module()`, `mutants()`) and the `check` and `mutants` entries at `:109–110`.
- **Evidence:** CLAUDE.md ("Full test suites: run them with the sharded runner, `python3 ops/shards.py`") and CLUSTER.md §7 name only the shards runner, which runs pytest only (`grep -n cargo ops/shards.py` finds nothing). `cargo test` runs only from `cli check` (`git grep -n "cargo\", \"test\|cargo test" -- '*.py'` finds `cli.py:37` and the mutants' own commands). The mutants run only from `cli mutants`. `data/check/*.log` on the main checkout was last written 2026-10-28 14:01 UTC (10:01 EDT), so the Rust suite (`kernel/mm/tests/*.rs`, about 1,900 lines) and the C1.1/C5.5 mutants have not run in the routine since. The main kernel is frozen and unchanged, but `stage7` changes it.
- **Proposal:** one runner. Add a pytest item that runs `cargo test --release` in `kernel/` (and one that runs the mutants, or a mutants shard) so `ops/shards.py` covers everything. Then delete `cli check`, `cli mutants`, the two byte constants and the `importlib` loader (item 6).
- **Risk:** the swap could lose the mutants' coverage if the new item is skipped on nodes (the Lean build is `LOCAL_ONLY` for the same reason). Each mutant must still fail its named test.
- **Call:** the advisor (it changes the suite process CLAUDE.md names). High value: it removes one concept and closes a silent gap.

### 6. The mutants module loaded by path in two places, while a third imports it normally (≈10 lines)

- `cli.py:52–57` (`mutants_module`, the `importlib.util` spec dance) and `kernel/tests/test_mutants_apply.py:3–9`. `kernel/tests/test_mutants_classifier.py:1` shows that `from kernel.mutants.mutants import …` works as a namespace import.
- **Risk:** none; both tests cover it. If item 5 lands, the `cli.py` half goes with it. `import importlib.util` at `cli.py:8` then serves only `importlib.import_module`, which plain `import importlib` gives.

### 7. `ops/live.py gate`'s `Default|Unmasked` argument: a settled diagnostic (≈4 lines)

- `ops/live.py:7, 69` (`proc=PROC` threaded through `pod_spec`), `:456–459`. The diagnosis settled on `Unmasked` (`audit/cluster/gate-diagnosis.md`; `PROC = "Unmasked"` at `:42`; CLUSTER.md:151). The only test call passes `"Unmasked"` (`ops/test_live.py:313`). After the change `gate <digest>` writes `audit/cluster/gate.json`. The existing `gate-default.json` and `gate-unmasked.json` stay as records.
- **Risk:** low; covered by `ops/test_live.py`'s gate tests.

### 8. Run records cite PROGRESS.md for qualifications (3 lines; a stale-citation class the 2026-10-28 decision named)

- `gate/agent/campaigns.py:530, 796` and `gate/sweep.py:262` write `"qualifications": "PROGRESS.md, Qualifications, stage N"` into result files. PROGRESS is current-state and pruned under a cap. The qualifications' authoritative home is `audit/criteria.md`, beside each criterion (PROGRESS:62 says so). Point them at `audit/criteria.md, stage N`.
- **Evidence:** `audit/decisions.md:303` lists "PROGRESS.md citations in runner-imported files". Neither file is hashed by `harness_hash` or `search.identity`.
- **Risk:** regenerating the stage 2, 3 and 4 summaries would no longer be byte-identical to the recorded ones (`audit/stage3/null-summary.json` carries the string). Accept that, or change only what writes future records.

### 9. PROGRESS.md: repeats (≈4 lines)

- `:28` ("**Stage 7: parked** … slices 1-5 on `stage7`") and `:31` (numbered item 1, "**Stage 7, parked** …") say the same thing. Keep `:31`, which holds the owed items.
- `:37` (memory across campaigns) repeats `docs/future-work.md:11`. Leave one line that links there, or move the "unblocked, pre-register first" status into future-work and delete `:37`.
- `:14` restates CLUSTER.md §5 (what the mirror copies, "the only copy"). Keep only the digest, which is status.
- **Risk:** none. It also frees bytes under the 12 KiB cap.

### 10. `docs/future-work.md:3`: a stale gate clause (1 line)

- "none of this starts before the pilot answers whether the search controls false discoveries". The pilot's exits establish smoke evidence, not that answer (meta review §3, "semantic slop"). PROGRESS:37 already treats the memory question as "unblocked now that stage 4 has exited". Replace it with the rule as the human set it on 2026-11-08 (`audit/decisions.md:765` (b)): the positive-control study comes next, and an idea enters only through its own stage and criteria.

### 11. The `slow` pytest marker: declared and applied, never selected (3 lines)

- `pyproject.toml:6` declares it ("run by default"). `reference/tests/test_lean_differential.py` and `thesis/tests/test_registry.py` apply it. Nothing passes `-m slow` or `-m "not slow"` (`git grep -n "\-m slow\|not slow"` finds nothing), and the shards runner balances by recorded durations instead.
- **Risk:** none. `thesis/tests/` is not in the thesis manifest (it hashes the modules that `thesis.runner` and `thesis.report` load), but leave `test_registry.py` alone until the refreeze lands, to avoid a merge conflict.

### 12. Three file-hash helpers (≈5 lines)

- `gate/agent/campaigns.py:409–411`, `ops/jobs.py:40–41` and `ops/live.py:143–151` (the last also takes a prefix length). Keep `ops/live.py`'s as the superset and have `ops/jobs.py` use it. `campaigns.py` sits in another package and keeps its own (or uses `hashlib.file_digest` inline at its callers). Low value; do it when touching those files.

## Needs the human's call

### 13. CLAUDE.md:118: the Lean/OCaml engine plan is stale (1 sentence)

"A Lean engine with OCaml plumbing replaces both in its own stage between 7 and 8 … Don't start it early." The human deferred the language plan on 2026-11-08 (`audit/decisions.md:765` (a)). The paper's matching lines (`docs/whitepaper.tex:252, 514`) are already rewritten on `positive-controls`. CLAUDE.md is the human's file. Suggested replacement: "The proofs are Lean (`reference/lean`); the Lean engine with OCaml plumbing is deferred (`audit/decisions.md`, 2026-11-08). Every judged pilot result comes from one frozen kernel."

### 14. The `agent-real` mechanism: stage 3's one real campaign (≈780 lines), contingent on the positive-control design

- **What:** `gate/agent/campaigns.py`'s real-only functions `claims` (:414), `inputs` (:419), `check_ready` (:427–455), `run_record` (:472–489), `both_arms` (:492–534), `commit_promotions` (:537–548), `report` (:551–576), `real_attempt` (:579–585), `real` (:588–606) and `comparison` (:609–626): about 200 lines with spacing, plus the constants `REAL_REPORT_FROM`, `HOLDOUT_RECORD` and `NULL_SUMMARY`. Also `gate/tests/test_agent_real.py` (524 lines), `ops/live.py:56–57` (the workload) and its `"once"` handling, the three agent-real assertions in `ops/test_live.py:640–667`, `cli.py:106`, and the CLUSTER.md lines in item 3.
- **Evidence:** stage 3 exited (`audit/stage3/exit.md`). Its holdout claim is recorded and a spent holdout is never reused (CLAUDE.md, Holdout), so `real(...)` can only refuse or replay a report. `criteria/test_stages3to5.py` reads the recorded `real.json` and needs only `NO_CLAIM`, `audit_holds` and `cohort`, which stay.
- **Why a call:** the positive-control draft's PC.C6 (`positive-controls:audit/positive-controls-criteria-draft.md`) forces one synthetic finalist through "one ordinary release/claim", and Opus asked for a redesign. If the redesigned sentinel drives `both_arms`/`report`, this code is its tested release path. If it calls `gate/campaign.py` directly, it is dead. Decide when the PC criteria freeze, and delete in the same commit as that decision.

### 15. The BigQuery survey: `venue/sources.toml:648–664` and the `cloud` shell's Google tools (≈20 lines)

The entry has no `terms` record, so `ingest/terms.py` ignores it. It is a survey, not a certificate, kept in the certificates' home. The human configured that account (project `moneymachine-512800`, 2026-10-26). If no study plans to use it, the survey moves to `docs/future-work.md`'s on-chain section as one line, and the Google packages leave the flake. `terms.allowlist(retrieval=True)` is unaffected, so the thesis manifest does not change.

### 16. Not proposed: stage-exited one-off commands

`probes-top5`, `freeze-searcher`, `betas`, `truth`, `sweep-summary`, `holdout-size`, `witness`, `availability`, `execution`, the stage 5 source commands, `differential-run` and `null-agreement` are each 3–11 lines of wrapper over modules that later work reuses. The positive-control draft reuses `gate.markets.generate/write`, `oracle.json` and the beta bisection (`positive-controls:docs/whitepaper.tex`, PC2). `gate/tests/gpt_nulls.py` is C2.2's independent generator, and the 2026-11-04 NULLS revision needs it again. Removing them saves little and costs the reproduction path of judged results. Kept.

## Branches (after their freeze or landing; read-only here)

### 17. `thesis-refreeze`: seven test files named by review round (≈1,314 lines to fold)

`thesis/tests/test_refreeze_round4.py` (197), `_round5` (259), `_round6_inputs` (358), `_round7` (118), `_round8` (117), `_round9` (215) and `test_refreeze_t3.py` (50). Tests named by review round rather than by concept are the "criterion- or version-named files" of `audit/decisions.md:303`. Each round's tests also overlap the concept files the branch grows at the same time (`test_market.py` +448, `test_runner.py` +298, `test_snapshot_integrity.py`, `test_snapshot_schedule.py`, `test_funding_fill.py`). After the freeze lands, fold each test into its concept's file and delete the duplicates. Tests are outside `manifest_files` (which hashes only the modules that `thesis.runner` and `thesis.report` load), so folding them does not fork the version. Doing it before the freeze would only move the reviewed tree. Net size unknown until the overlap is read. Expect several hundred lines.

### Other branch notes

- `stage7` is parked (`audit/decisions.md:765` (a)) and 118 commits behind main (it has no `ops/shards.py`). Its `gpt_*` files are designed independent implementations. Nothing to erase until it resumes.
- `positive-controls` adds `audit/positive-controls-round2-design-check.py.txt`: a script stored as text under `audit/`. When the draft is adopted, keep the record but name the script for what it checks, beside the criteria.
- `code-style` (ruff format and check) touches most of the Python files above. Apply items 4–12 after it merges, or rebase it, to avoid churn.

## At the next fork (frozen identities: list only, do not touch now)

| Path | What | Identity | Size |
|---|---|---|---|
| `ingest/policy.py:11` | `SETTLEMENT_LATENCY`, referenced nowhere (the store and the kernel read `settlement_latency_ms` from their own policy). The only unreferenced top-level name in the repo. | thesis manifest (`ingest/policy.py` is loaded by `thesis.runner`) | 1 line |
| `kernel/DSL.md` | the derivation prose whose home is now the paper (paper :714; PROGRESS:26 already queues it). | `gate/tests/test_agent_dsl.py` pins its sha256; the agent workspace | tens of lines |
| `gate/agent/research.md` | copies the paper's ideas list verbatim (e.g. `:20` matches paper :461). That is deliberate (the agent's workspace has no paper), but it duplicates its home. At the next harness fork, generate it from the paper or cut it to what the agent needs. | `harness_hash` | 24 lines |
| frozen Python | CLAUDE.md's new typing and ruff rule applies to frozen code "at its next fork" (`gate/agent/{daemon,harness}.py`, `gate/search.py`, `sandbox/*`, the thesis manifest's modules). | `harness_hash`, `search.identity`, thesis manifest | n/a |

## Outside the repo

### 18. The advisor's auto-memory holds status that PROGRESS owns

`~/.claude/projects/-home-kevin-repos-moneymachine/memory/gpt-review-queue.md` ("Live state … as of 2026-11-02": C4.5 v2 running, B2 frozen, B3 draft) is wrong now and duplicates PROGRESS. MEMORY.md indexes it as "Live state". `overnight-budget-2026-11-04.md` was one night's budget. Delete both and their index lines. The quota notes (`argon-quota-2026-11-07`, `gpt-weekly-low-2026-11-08`) expire on 2026-11-13/14; delete them then. The advisor owns these files. This reviewer did not edit them.

## Checked and kept

- `gate/kernel.py:build`: used by `conftest.py:79`. GPT's earlier item 10 (`audit/erasure/review-gpt-1.md`) was mistaken.
- `ops/crossmachine.py`: the identity proof that the erasure passes themselves rely on (`audit/erasure/reproduce-*.json`).
- `ops/runaway.py`: the target of `ops/test_guard.py`, not dead.
- `thesis/tests/scoring_gen_states.json` (125 KB, generated): it splits the differential's random stream across cores, and regenerating it means walking the whole stream. Kept.
- `kernel/mm/tests/c41/*.f64`: the frozen kernel's fixtures.
- `docs/whitepaper.pdf`: CLAUDE.md requires it.
- `docs/research/**/media`: every image is referenced by its report.
- Databento (`ingest/databento.py`, `ingest/dbnconv`): ICE is pending the human's licence reading.
- `audit/stage6/effort.py`, `audit/stage5/purge.py`, `audit/stage6/bend-l5-PROOF.bendtt`: misplaced as the 2026-10-28 decision noted, but `audit/criteria.md:697` and the stage reports cite them by path. They are records; leave them.
- `.githooks/commit-msg` and `ops/commitcheck.py`: the `Why:` rule is already gone (`d06be20`). What remains checks UTC/EST pairing, which is current.
