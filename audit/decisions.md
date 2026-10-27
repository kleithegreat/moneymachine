# Decisions taken autonomously (audit record)

Append-only. Each entry gives what was decided, why, what GPT said and how to reverse it, under CLAUDE.md's autonomy rules. Decisions that cannot change a false-discovery or leakage outcome and are reversible are logged here directly. The others wait under "Decisions awaiting the human's review" in PROGRESS.md and move here once reviewed.

## Reviewed and approved by the human, 2026-10-23

- **2026-10-23: stage 6 exits with Lean adopted, and C6.5's frozen thread configuration recorded as a known limitation.**
  - **Why:** the same exit was rejected for the third time, and the remaining gap is performance reproducibility, which changes neither the ranking nor any decision (rule 3).
  - **GPT:** "accept Lean's selection and proceed with adoption, recording the benchmark configuration issue as a known limitation".
  - **Reverse:** reopen stage 6, restore `reference/benchmark.py` from git (deleted after `6e26fb7`), pin a thread configuration (environment and process affinity) in it, and rerun `benchmark-freeze` and `benchmark-run`.

- **2026-10-23: stages 7 to 9 keep their kernel changes off `main` until the pilot's judged runs are done.**
  - **What:** stage 7's criteria are pre-registered now. Its kernel-changing code stays on a branch until C1.4, the stage 2 sweeps, stage 3's campaigns and stage 4's swarm smoke have recorded their kernel hash.
  - **Why:** the paper begins stages 7 to 9 after the pilot so that "every judged pilot result comes from one frozen kernel". Stage 5 exited before those pilot runs.
  - **GPT:** not asked; this follows the paper's text.
  - **Reverse:** merge the branch earlier, and accept that the pilot's later judged runs record a different kernel hash.

- **2026-10-23: event rows known at eventTime + δ, in `mm`'s loader and the store (stage 5).**
  - **What:** event counts cover knownAt in (H + δ − 1h, H + δ], and each row is known at its tick. That is a one-line change to `market.rs`'s knownAt rule, made in stage 5 despite stage 6's "mm not modified" instruction.
  - **Why:** C5.5 and DSL.md define the window as ending at the tick. The old window ended at H and counted items up to 120 s late. No leak either way.
  - **GPT:** it found the mismatch (third stage 5 review). A fresh independent implementation from it agrees on 2,000 cases.
  - **Reverse:** restore `_ => long(r, "eventTime")?` for event datasets and the old window in `ingest/events.py` (`c007644`).
- **2026-10-23: C6.1 judged for Lean only, with Bend's L5 reported but not accepted; C6.5's effort reported as a recovered proxy.** Both are labeled amendments under the stage 6 criteria.
  - **Why:** Bend's statements could not be frozen with review, and effort was never instrumented. Neither can change a false-discovery outcome, since Bend is not adopted and effort cannot change the ranking.
  - **GPT:** its second review asked for these to be resolved or acknowledged.
  - **Reverse:** delete the amendment block, and judge C6.1 and C6.5 as written (both unmet).
- **2026-10-23: the C6.4 corpus needs at least 1,000 distinct generated programs, not all distinct.**
  - **Why:** both sides of a rewrite instance can coincide (1,017 distinct of 1,024). C6.4 asks for at least 1,000 programs.
  - **Reverse:** `complete()` in `reference/differential.py` (`f7f9091`).
- **2026-10-24 21:30 UTC (17:30 EDT): a third terms basis, "operator decision", for Hyperliquid and Polymarket.**
  - **What:** their records said "official API", but neither quote permits our use: Polymarket's only quote is "Trading is blocked in the United States on polymarket.com", and Hyperliquid's documents the API without terms. Both rest on the human's decisions of 2026-10-23 (paper §5: where the terms restrict the operator rather than the access, use of the read-only public data is the operator's decision). Nothing fetched changes.
  - **GPT:** its whole-project review of 2026-10-24 found that a structurally valid record was being called certified whatever its quote said.
  - **Reverse:** set both records' basis back to "official API" and drop the basis from `BASES` in `ingest/terms.py`.
- **2026-10-24 21:55 UTC (17:55 EDT): the agent sandbox enforces its boundary at the operating-system level (`sandbox/`, paper §3).**
  - **What:** GPT's whole-project review found, and a subagent confirmed, that an agent could overwrite `./mm-agent` (an ordinary script in its writable workspace) with any code and run it through the permitted Bash command, with the host network shared, all of `/nix` mounted (eight flake snapshots of the repo are there) and the host environment inherited; a planted `json.py` in the workspace would also have run inside the unmodified client. Now:
    - the client is a read-only mount, run with `python -I`;
    - the sockets are in a read-only `/tool`;
    - only the closure of the CLI, Python and coreutils is mounted;
    - the environment is cleared;
    - the sandbox has its own network namespace, whose only path out is `sandbox/egress.py`'s relay admitting `CONNECT api.anthropic.com:443`, each request logged to `egress.log`;
    - the wall-time limit fires whether or not the agent prints.
  - **Why straight here:** it only removes channels, and no agent session has run yet. A real haiku session through it made one client call; `curl` and `python3` were denied, and the relay saw only api.anthropic.com.
  - **Reverse:** `git revert` of the commit.
- **2026-10-24 22:30 UTC (18:30 EDT): fixes from GPT's whole-project review, before any judged sweep or campaign.**
  - **Holdout return over the window only.**
    - **What:** the kernel's holdout result is an account starting the reported window with INITIAL: equity rescaled by the equity just before the window, and only the window's events. Until now the window's equity was left in the full replay's units, so `total_return` (the promotion rule's "net holdout return > 0") included the search period's PnL; a test strategy showed −40.2% for a window whose own return was −0.35%. Fills, fees, funding and turnover also covered the full trace.
    - **Why straight here:** it makes the frozen rule hold as written, and no judged evidence used the field.
    - **Reverse:** `reported()` in `kernel/mm/src/main.rs`.
  - **Calibration ledgers kept.**
    - **What:** each baseline campaign runs in `data/campaigns/<sweep>/<id>/` and keeps its ledger and the holdout's spent record there, xz-compressed (about 7 MB for a G400 campaign); only the simulated market, which its id regenerates, is deleted. Until now the whole work directory was deleted, ledger included.
    - **Why straight here:** CLAUDE.md never erases experiment ledgers.
    - **Reverse:** `gate/campaign.py`.
  - **Interrupted campaigns.**
    - **What:** a campaign whose directory exists without a recorded result is recorded as a crash, which counts as a promotion, and is never rerun. One `campaign.resume` serves the sweeps and the agent series. Until now a killed sweep worker's campaign was silently rerun.
    - **Why straight here:** it applies the frozen rule "every market started counts, crash = promotion" and can only add promotions.
    - **Reverse:** `gate/campaign.py`.
  - **Holm and the betting p-value fail closed.**
    - **What:** `holm` raises on any p-value outside [0, 1] or NaN, where a NaN used to become an adjusted 0 and pass; `holdout_pvalues` raises on non-finite wealth.
    - **Why straight here:** it can only remove promotions.
    - **Reverse:** `gate/gate.py`.
- **2026-10-24 23:20 UTC (19:20 EDT): before stage 3, from GPT's whole-project review.**
  - **What:**
    - finalist programs come from the arm's own trial rows (`gate.trials`), where an equivalent program from another arm could have supplied them;
    - a selection's `seen_through` is the last disclosure of any agent;
    - each market directory pins its dataset version (`version`), which every `mm` call passes;
    - the kernel records each experiment's trial key (`experiments.trial`), replacing Python's `trial_key`;
    - `mm holdout` reads its batch whole from a file and accepts it only if its trials are exactly the campaign's gate selections, before claiming the window under an exclusive lock (I11).
  - **Why straight here:** each makes a frozen rule hold as written (one holdout batch of the frozen finalists), changes no threshold, and precedes every judged campaign.
  - **Reverse:** `git revert` of the commit.
- **2026-10-24 22:27 UTC (18:27 EDT): correction to the times of the four entries above.** Their times were estimated, not read from the clock. Their commits give the actual times: the terms basis and the sandbox at 21:38 UTC (17:38 EDT, `5a44a4e`), the holdout-return fixes at 21:53 UTC (17:53 EDT, `db5b881`), and the before-stage-3 fixes at 22:22 UTC (18:22 EDT, `b2c0007`). From now on an entry's time is read from `date -u` when it is written.
- **2026-10-25 01:54 UTC (2026-10-24 21:54 EDT): the thesis track records what registration decides, before the stage 10 start (GPT's whole-project review).**
  - **What:**
    - registration reads t_r from the clock under the ledger's lock, after the inputs are fetched, so commit order is t_r order and slow inputs never backdate a thesis;
    - it records N, size, the reservation b, the fee, the cost cells, the cost fallbacks and p_ref with its window counts;
    - replays size from those records (`positions.admit` is the only sizing), resolutions and fills use the recorded costs, and the report scores the resolution records and recorded base rates;
    - a missing funding hour leaves an outcome, a base-rate window or a managed return unresolved (C10.4 revision of this time);
    - candles are known at close + δ;
    - the manifest covers every module the runner and report load, the kernel's sources and the data files, read once per process;
    - the resolver and mark loops log failures and continue;
    - cache writes are atomic and locked;
    - one runner per root;
    - the HL client charges every attempt.
  - **Why straight here:** each makes a frozen stage 10 rule hold as written (C10.1's commit-time t_r and concurrency, "never assumed zero", the frozen track version), changes no threshold, and precedes any live registration. The C10.4 revision is the criterion's own path for an ambiguity found before live registration.
  - **GPT:** found the gaps; it updated its own independent scorer from the revised SCORING.md, and the differential agrees on all 1,000 sets.
  - **Reverse:** `git revert` of the commit.
- **2026-10-25 23:54 UTC (19:54 EDT): reviewed by the human.** Approved: the merge amendment's extension to boundary polls with the cloud recorder at 600/min (merged by completeness across clock-verified hosts, host-tagged, as specified), and the C2.6 amendment, which was then found infeasible before any sweep and is suspended (`audit/criteria.md`, C2.6; PROGRESS.md, Blockers). The human also put vendor permission requests on hold, and `docs/permission-requests.md` was deleted.
- **2026-10-26 01:28 UTC (21:28 EDT): stage 7's rule language (`kernel/RULES.md`, C7.6) revised once from two reviews and frozen as version 1 on branch `stage7`.**
  - **What:** GPT (`audit/stage7/rules-review-gpt.md`) and a fresh-context Opus subagent (`audit/stage7/rules-review-opus.md`; labeled, since GPT first seemed unavailable) reviewed the draft independently, and agreed on its defects: floor overflow, backdating by a floored time, undefined strict JSON, no code for a malformed row, and no resolver. The revision:
    - adds a lower-bound check (every accepted rule is at least one named field and every declared dependency);
    - puts the correction and derived-dependency bounds in the resolver, where no rule can remove them;
    - defines JSON and integer spelling exactly, adds `R_ROW` and a precedence order, specifies the resolver, and fixes a conformance case format.
  - **Choices between the reviews:**
    - malformed rows get their own code (Opus), not `R_FIELD_TYPE` (GPT);
    - integers longer than 19 digits may be treated as out of range, which is equivalent to GPT's unbounded exact value and avoids parser limits;
    - there is no witness-or-fallback operator: an absent field rejects the row, and a certificate decides which rule (a claimed time, a witness, or `fetchedAt` alone for prospective use) covers which time scope.
  - **Next, before any implementation:** freeze the C7.6 suite (hand cases with expected results, the generator, seeds and the comparison procedure). GPT's independent implementation follows from this document alone.
  - **Reverse:** a new rule-language version.
- **2026-10-26 01:38 UTC (21:38 EDT): reviewed by the human.** The C0.7 regime diagnostic on Hyperliquid's archived books is approved, within the $20 budget, as a labeled diagnostic that decides nothing, to run after stage 0 is committed. A pre-holdout cost table for stage 3 is proposed for the human's review (PROGRESS.md).
- **2026-10-26 02:01 UTC (22:01 EDT): stage 7's declarations (`kernel/SOURCES.md`) and certificates (`kernel/CERTIFICATES.md`) revised once from GPT's review and frozen as version 1 on branch `stage7`.**
  - **What:** GPT's review (`audit/stage7/sources-review-gpt.md`) found 18 gaps; all were adopted:
    - availability bases enforced through the rule, never overridden by a certificate;
    - access authorization, holdouts included, separate from certification and over the whole transitive closure;
    - scope as explicit grants (entity, column, event-time and use-time intervals), and certificates authoritative only as verifier-written ledger records;
    - transitive preflight, derived lineage by upstream revision identities, and positive coverage evidence for zero counts;
    - `derived-inherits` narrowed to properties the transformation provably preserves;
    - a role contract table, held cadences with period, phase and slot column, and exact delivery order;
    - binding schema and unit validation, an executable policy, explicit supersession, the operator CLI, the registry and rule-byte identity, and a migration annex required before C7.4.
  - **Checked against the kernel:** a held input takes the last delivered observation whole, whatever its event time, and an event value counts only at the tick of its own hour (`machine.rs`), as the revision states.
  - **Reverse:** a version 2 of either document.

## 2026-10-26 05:18 UTC (01:18 EDT): funding priced at the latest bar opened by its hour (branch `post-stage0`)

- **What:** a held coin's funding at hour h is priced at the open of its latest bar opening at or before h, the lookup the marks already use, instead of the bar opening at h − (h mod BAR). A missing funding rate still aborts with `R_SETTLEMENT_MISSING`.
- **Why:** the branch's fix (a missing payment aborts instead of paying zero) aborted every search run whose last step held a position. The store is half-open on bar close, so the bar opening at end − BAR closes at the holdout start and lives in the holdout, while the last step settles hour end − BAR at that bar's open. Fills already avoid this bar (`b + 3·BAR ≤ end`). The paper's rule for funding (§Prices: "valued at the latest earlier reference when the hour's own is missing") removes the case. On complete data every price is unchanged; only a missing price bar now settles at the earlier open instead of zero (main) or an abort (the branch), and it never reads a holdout row (I8).
- **GPT:** not consulted; this follows the paper's stated rule and changes no result on complete data. It reaches GPT with the merged kernel in the next red-team round.
- **Reverse:** revert the commit on `post-stage0` (3273063) before the merge.

## 2026-10-26 15:51 UTC (11:51 EDT): stage 0 exits with C0.7's coverage failure as a qualification (human decision)

- **What:** C0.7's coverage failure on the judged window (BTC sell $1k 0.894, SUI sell $10k 0.882, kPEPE sell $10k 0.817) is a recorded qualification of the pilot, never a pass, and stage 0 exits with it (`audit/criteria.md`, C0.7). Stage 2's sweeps and stage 3 proceed on C0.7's table. No redesigned archive equivalence check: the archive table lapsed when its frozen check failed (`audit/stage3/archive-equivalence.json`).
- **Why (as proposed):** no single quantile of a one-day constant model met both of C0.7's limits on the spent window, so retrying windows would fit the criterion; the understatements are at most 0.5 bps against a 4.5 bps taker fee, and the pilot validates machinery.
- **Reverse:** a C0.7 amendment adopted by the human, with the results that use the table rerun under it.

## 2026-10-26 15:51 UTC (11:51 EDT): stage 10 runs on C0.7's committed table (human decision)

- **What:** stage 10 (track `thesis-34a49c19a8f9`, frozen 2026-10-26 15:20:50 UTC) charges the committed C0.7 cells, and every stage 10 result carries C0.7's qualification. Moved from "Decisions awaiting the human's review".
- **Reverse:** stop `thesis-run`, refit the table, and freeze a new track version.

## 2026-10-26 17:25 UTC (13:25 EDT): the licensing boundary for stage 8 sources (human decision)

- **What:** a source whose terms restrict AI or LLM use (CME data through Databento, Norgate, Nasdaq-originated data and the like) is *kernel-only*: its rows enter only the deterministic kernel and gate, and research agents see only aggregate kernel outputs, as the stage 3 brief already states ("You cannot see the data"). Sources whose terms allow it stay readable by agents. No written permission requests to vendors. The human accepts this reading of the terms; training is off on all of the human's Claude and ChatGPT accounts.
  - **May cross:** full schemas and metadata; evaluation reports by year and regime, contribution by instrument and class, turnover, exposure, hit rate, results split by the strategy's own condition, drawdown timing; coarse descriptive statistics.
  - **Never crosses:** anything that reconstructs rows, such as fine-resolution equity curves (a long-only single-instrument curve is the price series) or any per-date value lookup.
  - **Design:** paper §9 (multi-asset research), written now: the role is a declaration field, and the boundary is a frozen list of permitted report fields with minimum aggregation, tested by attempted reconstruction from single and combined reports. Implementation follows stage 8's ordering.
  - **This session:** small amounts of vendor data may be seen while debugging, but counts, hashes, schemas and test results are preferred to printed rows.
- **Also decided:** the stage 8 scope manifest's selection rule 1 (keyless, no account) is superseded: accounts are fine under the human's name and email. The manifest is revised per its own rule (dated, reviewed, before affected evidence is inspected; `audit/stage8/scope-manifest.md`), from the documentation-only source survey (`audit/stage8/sources-survey/`). Purchases (Databento, Norgate, Massive) are undecided and listed under Blockers.
- **Reverse:** a human decision; a source's role is a declaration field, so changing it is a new declaration version.

## 2026-10-26 17:30 UTC (13:30 EDT): GPT's sandbox also denies `execute`, `task` and `subagent` (human request)

- **What:** opencode's Code Mode tool `execute` runs JavaScript whose `fetch()` reaches the web without the `webfetch` permission, and its sub-agent tool was not denied either. Every GPT directory's `opencode.json` now also denies `execute`, `task` and `subagent` (CLAUDE.md, Subagents and GPT).
- **Which past runs it could have touched** (`audit/gpt-sandbox/findings.md`, from opencode's session store): only the stage 8 documentation survey used `execute`, with web access allowed on purpose. Five runs from directories inside the repo, under configs written before `external_directory` was denied, read `PROGRESS.md`: four reviews, and `derived3`, GPT's independent implementation of the derived event counts (C5.5) on 2026-10-22. It saw status and criteria summaries, no source code. No other independent implementation or red-team round used a tool outside its directory.
- **Queued for when GPT is available** (it hit its ChatGPT usage limit at about 17:20 UTC): the live probes of `execute` under the old and new configs, and a clean reimplementation of the event counts from `derived.md` alone, differential-tested against ours.
- **Reverse:** the denials are configuration; removing them restores the gap.

## 2026-10-26 18:27 UTC (14:27 EDT): the Treasury par yield feed certified as a public-domain federal work (human decision)

- **What:** the Treasury daily interest rate XML feed (par yield curve, bill rates, long-term rates, real yield curve, real long-term rates) is certified with basis "operator decision" (`venue/sources.toml`, `treasury-yields`): a US federal government work in the public domain, published as a documented developer feed whose page states no terms. Recorded by the data layer, one feed per data set and year. The blocker is removed.
- **Reverse:** remove the record and its feeds.

## 2026-10-26 18:27 UTC (14:27 EDT): Databento (CME) and OECD certified from the full terms the human saved in a browser

- **Databento, CME futures (`databento`):** kernel-only, basis "operator decision" under the licensing boundary. Read in full: Databento's User Agreement and Exchange Data Policy, CME's Schedule 5 version 5.04 and notice DS-45 (PDFs in `data/terms/`, hashes in the record). The AI prohibition in these texts is Schedule 5 §7.1(c), the notice for public websites displaying CME data, which DS-45 places among the website-display updates; DS-45's other terms limit use to internal business purposes. CME's updated Subscriber Addendum, which governs subscribers of a distributor, is not among these texts. The human's reading stands: kernel-only use is internal deterministic processing. ICE is not covered.
- **OECD (`oecd`):** agent-readable, basis "permitting clause": "you can extract from, download, copy, adapt, print, distribute, share and embed Data for any purpose" and "You may use one or more OECD-developed application programming interfaces". Its STES revisions are about 357 MB of CSV per country (all editions since 1999), so they are recorded quarterly, after stage 2's sweeps free memory. The blocker is removed.
- **Reverse:** remove the records.

## 2026-10-26 20:25 UTC (16:25 EDT): stage 10's identity covers its retrieval allowlist, not the whole source registry

- **What:** five registry records added today for the data layer (`fed-ddp`, `nyfed`, `databento`, `oecd`, `treasury-yields`) were marked `retrieval = true`, which puts a host on the thesis agents' fetch allowlist; they are set to `false`, restoring the allowlist exactly (`thesis/tests/test_retrieval.py` caught it). The running track (`thesis-95bfd9f7ebc9`) read its allowlist at its start, before any of them existed, so no session could fetch from them. Stage 10's manifest hashed all of `venue/sources.toml`, so any data-layer registry edit would make a restarted `thesis-run` refuse to start; the track's identity now includes the sorted retrieval allowlist it reads instead of the registry file. This changes the identity, so the track is refrozen.
- **Reverse:** revert the harness change and refreeze.

## 2026-10-26 21:54 UTC (17:54 EDT): mm's market-loader memory fix lands in stage 7's kernel rewrite (human decision)

- **What:** the per-row `HashMap` loader (3.6 GB of `mm` for a ten-year market, `audit/stage2/campaign-profile/memory/`) is replaced by stage 7's generic loader, together with the profile's CPU speedups, instead of a patch to the current kernel. The pilot's remaining runs keep the current kernel: stage 3 is paced by the subscription, stage 5's events calibration fits at about 1 GB a campaign, and stage 8's calibration, which needs the fix, comes after stage 7.
- **Why:** proposed by another Claude session and accepted by the human in this session ("i think this seems reasonable"); one loader rewrite instead of two, and no kernel change between the pilot's judged runs.
- **Reverse:** patch the current loader between judged runs, with the corpus differential and a new cross-machine test.

## 2026-10-26 23:19 UTC (19:19 EDT): four human decisions on stage 7 and stage 8 (typed by the human in this session)

1. **Pre-annex recording: approved.** The stage 8 recording exception extends to every certified source the human authorizes, with integrity-only inspection (labeled amendment in `audit/criteria.md`, stage 8). Databento's outright statistics and daily-bar pulls resume. *Reverse:* revoke the amendment and stop the pulls; recorded data is then not used before an annex.
2. **Bitemporal resolution: approved.** Each revision is delivered at its own knownAt and a tombstone as a retraction: dated revisions of RULES.md §6 and C7.6, C7.4's identity limited to single-revision keys; the pilot keeps version 1's snapshot semantics, recorded as a qualification; stage 7's law statements are frozen. *Reverse:* a further dated revision before any proof is judged.
3. **Kernel-only reports:** under the licensing boundary already decided, the frozen aggregate report fields derived from CME data may go to research agents and to GPT and Opus reviewers; raw rows never do.
4. **Debugging allowance:** stands as written. For kernel-only sources, coding sessions default to integrity-only views; any accidental disclosure of rows is logged in `audit/stage8/exposure.md`.

## 2026-10-27 01:33 UTC (21:33 EDT): I5's tolerance scales with the run's peak equity (human decision, typed in this session)

- **What:** I5 checks |equity − reconciled| ≤ 1e-9 · max($10,000, |equity|, the largest |equity| the run has reached), instead of the current equity alone. Dated revision in `kernel/INVARIANTS.md`; `mm` and stage 7's Lean reference follow.
- **Why:** `betas` crashed on `R_ACCOUNTING` (β 0.25, market `oracle-cal-long-N2-10`, "0 vs -0.00044" after a bankruptcy): the reconciliation terms carry rounding error proportional to the magnitudes the run has reached (equity peaked at 10^10 times its start), so a correct run failed a tolerance scaled by current equity. Runs that did not abort are unchanged.
- **Conditions (human):** before the mixed sweep uses the new `mm`, it reproduces a sample of the recorded null campaigns byte for byte (results and ledgers apart from the kernel identity), I5's mutant is still caught, and the cross-machine test is rerun with it on every worker.
- **Reverse:** restore the current-equity scale; runs that hit the case abort again.

## 2026-10-27 14:40 UTC (10:40 EDT): stage 2's s = 3 calibrations

1. **N3-s3 amended to s = 2.5 (human decision, typed in this session).** N3's oracle cannot reach Sharpe 3: on the calibration's markets its net Sharpe is 2.09 at β 0.05, 2.55 at 0.06, 2.21 at 0.08, 2.45 at 0.12 and 2.04 at 0.2. The cell runs at s = 2.5, bisected on [0.044, 0.06], where the oracle's Sharpe rises; labeled amendment in `audit/criteria.md`, C2.5. *Reverse:* drop the cell and report it as unattainable.
2. **N2-s3 bisected on [0, 0.08] (autonomous, rule 1: cannot change a false-discovery outcome, reversible).** On [0, 0.05] it saturated at the bound (Sharpe 2.36); N2's oracle reaches 3.01 at 0.08 and rises up to there, so the frozen criterion ("β is set so that the oracle's net Sharpe is s") is met at β 0.07261 (Sharpe 3.0). The range is code, not criterion. *Reverse:* restore [0, 0.05].
3. **The paused partial mixed run is set aside unjudged (human decision).** Its plan (5769dc6) fixed the saturated s3 betas; its shards ran from 03:31 to 03:32 UTC and were paused. Their records move to `data/campaigns/fanout/mixed-aside-20261027/` on every host, are never merged or judged, and a fresh plan runs with the corrected betas.
4. **Calibration markets run two at a time within a step (autonomous, rule 1).** `sweep.oracle_returns` evaluates its 20 markets through a small thread pool when asked; each market is seeded by its id, so the values are identical. *Reverse:* one at a time.

## 2026-10-27 16:26 UTC (12:26 EDT): three crashes in the mixed sweep from a memory limit, recorded as the protocol says (rule 1)

- **What:** prodesk5's mixed shard stopped silently after c25-N2-long-66 with 126 campaigns started and 123 recorded; two long-cell campaigns at once likely exceeded its 6 GB scope (each peaks near 2.5 GB). Under the sweep's frozen resume rule, a started, unrecorded campaign is recorded as a crash, which counts as a promotion, and is never rerun; the resumed shard did that and ran the 4 unstarted campaigns with one worker (4,900 MB cap).
- **Why rule 1:** following the frozen rule cannot raise false discoveries (a crash counts against the searcher), and the crashes are reported as infrastructure failures beside the sweep's results.
- **Reverse:** none needed; the rule is the protocol's.

## 2026-10-27 16:37 UTC (12:37 EDT): correction to the previous entry: a concurrent resume, first record kept (rule 1)

- **What happened:** the resumed prodesk5 shard was started while the original was still running (my liveness check printed only the system unit's state and hid the user scope's). The resume recorded c25-N2-long-77 and c25-N2-long-81 as crashes; the original then recorded 77's result too, so 77 appears twice (the third campaign started before the stop had recorded its result).
- **Decision:** each id's first record is its outcome, as the sweep's resume rule treats it, so 77 and 81 count as crashes (each counts as a promotion; conservative). The file as recorded is kept beside it (`fanout/mixed/prodesk5/mixed.jsonl.as-recorded` on prodesk5).
- **Reverse:** take 77's later result instead; it can only lower the promotion count by one.

## 2026-10-27 17:48 UTC (13:48 EDT): correction to the two entries above on prodesk5's mixed shard

- **What was wrong:** the shard never stopped, and no memory limit was involved. It was alive, running c25-N2-long-77 and -81, when my faulty check (system unit only) read it as dead. The resume recorded those two as crashes (not three); the original then finished 77 with 0 promotions and died on `FileExistsError` for c25-N2-long-88, which the resume had created, killing 81 mid-run.
- **Effect:** the recorded figures stand as decided (first record kept; both count as crashes). Without them, from 77's own result and 81's seeded rerun, N2-long's FDR is 0.00 instead of 0.02 (reported, not judged) and power is 0 either way (`audit/stage2/n2-long-crashes.md`).
- **Fix:** `campaign.resume` now locks the sweep's log for the whole run (f668d2f).

## 2026-10-27 18:32 UTC (14:32 EDT): human decision: fix the DSR screen before stage 3

- **What:** C2.6 failed on the current sweeps (`audit/stage2/c26-failure.md`): the screen's benchmark grows with the cross-trial spread of Sharpe ratios, which a real edge widens, so nothing is screened. The human ruled it a design defect: re-derive the screen (benchmark from the Sharpe estimator's null sampling variance over the effective number of trials, never the observed spread), spec first with a dated human-approved revision, GPT's independent implementation and a differential test, an offline development preview on the existing ledgers, then a rerun of stage 2 with fresh ids on all four machines, judged only on evidence after the revision, and reviewed by GPT. Stage 3 starts after that exit.
- **Recorded:** the failure stays in the audit record as it stands.
