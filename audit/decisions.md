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

## 2026-10-27 18:34 UTC (14:34 EDT): where the revised screen is specified, and which stage 2 evidence stands (rule 1)

- **Spec home:** the human named SCORING.md and the paper. `thesis/SCORING.md` specifies only the stage 10 thesis track and has no screen; the gate's frozen spec is criteria stage 2, Gate, with paper §8. The revision went there (criteria revision of this date; paper §8), so the gate has one home. Reverse: move the Gate text into a spec file and point the criteria at it.
- **Skew and kurtosis terms:** the human asked for the null sampling variance "with skew and kurtosis terms". In the Sharpe estimator's asymptotic variance those terms are multiplied by S, so at the null's boundary S = 0 they vanish and the variance is 1/(T − 1); they stay in each trial's own DSR denominator. Recorded in the revision's derivation. Reverse: none needed unless a finite-sample variance is preferred, which would only raise S0.
- **Evidence:** C2.1's fixed probes and C2.2 do not involve the gate, so their evidence stands; C2.1's top-5 probes (drawn from C2.4 campaigns), C2.3 and C2.4 to C2.6 are judged on evidence after the revision. Cannot change a false-discovery outcome: the reused evidence is independent of the screen. Reverse: rerun C2.1's fixed probes and C2.2.

## 2026-10-27 19:01 UTC (15:01 EDT): arch's StepM patched in the flake to upstream's fix (rule 1)

- **What:** the screen preview hit a crash in `arch` 8.0.0's `StepM.compute`: its step-down loop compared the last step's rejection count with the number of models instead of the cumulative count, so once every screened model was superior it reran SPA on zero models (`ValueError: zero-size array`). It never ran before: the frozen screen admitted nothing. Upstream (bashtage/arch, main) has exactly this fix (`len(all_better_models) < self.k`); `flake.nix` applies it to arch until a release carries it, with a regression test (`test_stepm_keeps_every_model_when_all_are_superior`).
- **Why rule 1:** it makes StepM what the spec names (arch's StepM, Romano and Wolf's step-down), and it cannot raise false discoveries: without it, such campaigns would crash, and a crash counts as a promotion. Every host runs the flake, so all get it.
- **Reverse:** drop the override from `flake.nix`.

## 2026-10-27 19:05 UTC (15:05 EDT): the first round's stage 2 evidence moves to audit/stage2/round1/, and its data to data/campaigns/round1/ (rule 1)

- **What:** `sweeps.json`, `c21-top5.json`, `mixed-hosts.json`, `fanout-mixed.json` and `fanout-truth.json` moved by `git mv` (contents unchanged; history kept); the sweeps' results and kept ledgers moved within `data/campaigns/` to `round1/`. The rerun's evidence takes the canonical paths the criteria tests read, so they judge only the revised gate's round (r2), and skip until it exists. The sweeps' ids carry the round (`sweep.ROUND`), so no id repeats across rounds.
- **Why rule 1:** a file move that keeps every record; it cannot change a false-discovery outcome.
- **Reverse:** `git mv` back.

## 2026-10-27 21:17 UTC (17:17 EDT): a candidate mm binary briefly replaced the shipped one (incident; rule 1)

- **What happened:** building the loader-memory candidate with `cargo build --release` overwrote `kernel/target/release/mm` (shipped `52db7b68…`) with the candidate (`3a732069…`) from 21:11:57 to 21:16:48 UTC; I restored the shipped binary atomically from a worker's byte-identical copy. Exposed: only the development screen preview, whose holdout batches started in that window used the candidate (c25-N2-long-75 and -84 among them). Not exposed: the stage 10 track runs its own pinned binary (`data/thesis/bin/mm`, `0aff52fc…`) and its ledger has no experiments; no judged sweep was running.
- **Effect and handling:** the candidate must be bit-identical to ship (its gate: the corpus differential and byte-for-byte reproduction of recorded campaigns). If it passes, those preview lines are unaffected; if not, the preview's campaigns from that window are rerun on the shipped binary. Candidates now build in their own target directory (`.gitignore`: `target*/`).
- **Reverse:** none needed.

## 2026-10-27 21:33 UTC (17:33 EDT): C6.4's corpus check leaves out the markets' version pin (rule 1)

- **What:** running C6.4's frozen corpus differential for the loader candidate (test 7(c)), the null markets failed "does not rebuild as frozen". Every data file matched the frozen hash; the only difference was the two-byte `version` pin that market directories gained after the corpus froze (content `1`, the version their store files carry). The edge markets matched fully. So the judged C6.4 run had been unrunnable on `main` since that change. `reference/differential.py`'s `market_hash` now leaves the pin out; with that, all six markets match their frozen hashes.
- **Why rule 1:** it restores the check's meaning (the frozen market data, hashed file by file) under the newer layout; nothing it verifies is loosened, and it cannot change a false-discovery outcome. Also: `DUMP` now honours `CARGO_TARGET_DIR` as `gate.kernel.MM` does, so a candidate's `mmdump` is the one run.
- **Reverse:** hash the pin again (and rebuild the corpus's frozen hashes, which would need a new freeze).

## 2026-10-28 02:04 UTC (22:04 EDT): round r2's mixed ids rebalanced by a dated addendum to their plan (human request; cannot change a false-discovery outcome)

- **What:** gmktec joined round r2 late (its preview tail), so its null shard ends about 04:10 UTC while this PC, prodesk7 and prodesk5 would have finished near 03:00 to 03:30 and sat idle (CLAUDE.md, Performance). No host had started its mixed step, so every mixed id was never started; the addendum in `audit/stage2/fanout-mixed.json` reassigns all 700 by the plan's own smooth weighted round robin with weights from measured rates (this PC 541, prodesk7 43, prodesk5 116, gmktec 0), sized so the three finish together around 03:15 UTC. Each host's mixed step reads the plan when it starts, so the original assignment is never run; gmktec's finds nothing; no id can run on two hosts, and the merge's exactly-once check still guards it.
- **Not moved:** gmktec's remaining null ids. Its running shard fixed its id list at start and has no drain channel; stopping it would kill campaigns in flight, which count as crashes in judged evidence. Its tail (about 04:10) stays; the cluster's test 8 can use the other hosts meanwhile. The Jobs path removes this limit (an Indexed Job's pods take the next index wherever there is room).
- **Why it cannot affect a false-discovery outcome:** campaigns are deterministic by id, and cross-machine tests 1 to 7 are identical on every host.
- **Reverse:** none needed; the original assignment is in git (6404245).

## 2026-10-28 06:07 UTC (02:07 EDT): the SSH workers retired and cleaned up (the human's cleanup list); one ordering mistake on prodesk5

- **Done:** `~/mm-worker` removed on prodesk7 (12 GB), gmktec (7.7 GB) and prodesk5 (11 GB); Determinate Nix uninstalled on prodesk7 and gmktec by its own uninstaller, then checked: no `/nix`, no Nix units, no build users, no shell hooks. Every result they held had been copied back and merged first.
- **prodesk5 (its Nix predates us):** the list said to compute our dev profile's closure before deleting the folder; my command deleted the folder after the closure delete had refused (one shared path was live), losing the profile links that named our paths. I reconstructed "ours" as the closure of this flake's dev shell plus the one dead older dev-shell environment from our period (both holding this flake's Python environment and Rust toolchain), intersected with paths both dead and registered after we began (2026-10-26 20:00 UTC), and deleted those: 102 paths, about 6 GB. 158 more such paths are held only by other dead paths I cannot show are ours, so they stay for the host's own garbage collection; nothing live and nothing older than our arrival was touched.
- **Reverse:** none needed; the cluster replaces the workers.

## 2026-10-28 06:07 UTC (02:07 EDT): correction to the entry above

- The prodesk5 deletions summed to 107 paths (passes of 1, 34, 2 and 68, plus the two dev-shell environments), not 102; about 6 GB as stated.

## 2026-10-28 13:42 UTC (09:42 EDT): human decision: option Q, with (a) to (c) (GPT's review attached)

- **What:** stage 2 exits with C2.6's failure as a labelled qualification, a waiver of demonstrated sensitivity, never a pass (C2.1 to C2.5 met on round r2; `audit/stage2/exit-r2.md`). (a) Stage 3's qualification covers every promotion of its real campaign. (b) B = 1 stands, justified by NULLS.md's derivation (limited liability gives a null strategy at most the expected absorbed shortfall, so no-edge is claimed only for evaluations that never go bankrupt) and the measured rate (1 of 2,700 r2 null campaigns had an evaluation reach −B); stages 3 to 5 report it per campaign. (c) O1 (I10 generalized to a per-step loss cap at B = 0.2) is a provisional candidate for stage 7 only, carrying GPT's requirements; a better-powered B = 1 betting test is compared first, as development work behind the critical path.
- **Evidence:** `audit/stage2/bound-options.md` and `bound-options.json` (development), GPT's review `audit/stage2/bound-review-gpt-1.md` (Q defensible as a waiver; O1 not established safe; stage 3's narrower qualification and loss absorption flagged), the recheck `bound-recheck.jsonl`.
- **Reverse:** a round r3 under a decided bound, judged on fresh evidence; the waiver stays recorded either way.

## 2026-10-28 14:14 UTC (10:14 EDT): agent campaigns paced by the subscription's measured windows

- **What:** the fixed 5 h spacing is replaced (`gate/agent/campaigns.py`, `wait_for_room`). Each agent campaign (null series and the real one) starts only when, in every usage window the subscription reports (five-hour, seven-day), current utilization plus the most any recorded campaign used of that window stays at or below 0.8; until one is measured, a campaign is assumed to need 0.5. Utilization is read from one tiny model call's `rate_limit_event`, which is account-wide, so this session's and the human's own use are counted. Each result records its transcripts' tokens and cost and the windows read before and after it.
- **Why:** the human asked for pacing by measurement, net of this session's use (2026-10-27); the windows are that measurement, and token counts alone cannot be compared with limits the subscription does not state in tokens. Pacing only sets when a campaign starts, so it cannot change any false-discovery or leakage outcome; it prevents interrupted campaigns, which count as promotions. `sandbox/session.py` is untouched, since the thesis track's frozen manifest hashes it.
- **Measured at decision time:** seven-day window 0.90, resetting 2026-11-01 05:00 UTC (01:00 EDT); five-hour 0.45. So the stage 3 null series cannot start before that reset.
- **Reverse:** change `CEILING` or `FIRST_NEED`, or restore a fixed spacing; recorded results are unaffected.

## 2026-10-28 17:12 UTC (13:12 EDT): human decisions on the move to the cluster (`CLUSTER.md`, GPT's reviews in `audit/cluster/`)

- **Credentials move to the homelab.** The Cornell account's `claude setup-token` token as `CLAUDE_CODE_OAUTH_TOKEN`, and `BLS_API_KEY`, `BEA_API_KEY`, `EIA_API_KEY`, `SEC_USER_AGENT`. The advisor creates the Secrets with kubectl from local files, outside Git. No Databento or FRED key moves.
- **The credential reaches sessions as `CLAUDE_CODE_OAUTH_TOKEN`, passed by `sandbox/session.py`,** not as a copied `.credentials.json`: the CLI rotates refresh tokens, so a read-only copy dies within hours. One path, shared by stages 3 and 10. So:
  - stage 3's harness is refrozen now, before any campaign (none has run: the series log is empty, with no campaign directory);
  - stage 10 cuts a new track version at the move, and C10.5's window restarts at its freeze.
- **C5.3, revision "hosts"**, appended under C5.3 as written in the design.
- **Overlap.** Hyperliquid reconciles against the Oracle recorder, which is always on. The sources and datalayer recorders overlap 72 h or until the human's next reboot of this PC, whichever comes first; this PC's directories then close as hosts.
- **Spec fixes.** The mirror CronJob is an ordinary restricted pod, since NFS takes no idmapped mounts. `moneymachine-live`'s PriorityClass is negative and never preempts. A restic instance backs up the live ledgers beside the mirror.
- **Reverse:** run the workloads back on this PC from git, and delete the Secrets. The refreeze and the new track version are recorded and stay.

## 2026-10-30 01:25 UTC (2026-10-29 21:25 EDT): the recorder handoff by reboot, and the move's deletions

- **What:** this PC's `record`, `sources-record` and `datalayer-record` handed off to the cluster at the human's reboot (shutdown 2026-10-29 01:54 UTC (2026-10-28 21:54 EDT)), each at its last poll (`audit/cluster/handoff.md`), as the human directed. The 18:00 UTC (14:00 EDT) Hyperliquid handoff therefore needed no SIGTERM. Section 6's checks ran afterwards, against Oracle for Hyperliquid and against this PC's directories for sources and datalayer, and pass. The clock check is measured against Hyperliquid's server time, because the pods' `timesyncd` log holds only errors.
- **Deleted:** `ops/recorders-up.sh`, `ops/mm-recorders-up.service` and the `recorder-restart` command. `ingest/live.py`'s `restart`, `alive` and pidfile stay until the next thesis refreeze, because the frozen track manifest hashes `ingest/live.py` and editing it would fork the track version. This PC's recorder directories stay as closed hosts, since stage 0's judged windows read them.
- **Why:** with the local recorders gone, nothing on this PC starts or restarts a recorder. A deletion cannot change any false-discovery or leakage outcome.
- **Reverse:** restore the files from git (`git show 6f3fcfe:ops/recorders-up.sh`) and start the recorders on this PC; the cluster's StatefulSets keep recording meanwhile.

## 2026-10-30 01:30 UTC (2026-10-29 21:30 EDT): correction to the entry of 2026-10-28 17:12 UTC (13:12 EDT): no restic

- **What:** the entry's "A restic instance backs up the live ledgers beside the mirror" was reversed the same day by the human's changes to `CLUSTER.md` section 1, built in a7f0b3f (2026-10-28 17:50 UTC (13:50 EDT)): the restic CronJob, its step and the image's restic and rsync are gone. The mirror on this PC (`/srv/moneymachine/mirror/<volume>`) is the only copy of the live volumes, so every copy is compared with its source, ledger snapshots must pass SQLite's integrity check, a day file that shrank, changed or vanished is refused, and the daily `mirror-verify` re-hashes everything against the manifests. This entry was missing until a cold-start read of 2026-10-30 01:05 UTC (2026-10-29 21:05 EDT) found the record still describing restic.
- **Why:** the human's decision; a backup's presence cannot change any false-discovery or leakage outcome.
- **Reverse:** restore the restic CronJob from git (`git show a7f0b3f^:ops/live.py`) with a repository the human provides.

## 2026-10-30 01:30 UTC (2026-10-29 21:30 EDT): human decisions recorded only in PROGRESS.md until now, moved here as PROGRESS.md becomes a current-state document

Transcribed as PROGRESS.md stated them (last at 342b9fd); dated by when the human made them.

- **2026-10-23: the cloud recorder.** An Always Free Oracle `VM.Standard.E2.1.Micro` (`mm-recorder`, us-ashburn-1) under a $1 budget (`mm-free-tier-guard`) records Hyperliquid, the data layer and stage 5's sources. Setup: `ops/oci/provision.sh`.
- **2026-10-26: keyed sources and cloud accounts.** `.keys.env` holds FRED, BLS, BEA, EIA and `SEC_USER_AGENT`. AWS: IAM user `hyperliquid-data`, S3 read-only, us-east-1, a $20 monthly budget denied at 100 %, spending approved up to $20 in total, for Hyperliquid's requester-pays archives, listed and reported before any download. Google Cloud: project `moneymachine-512800`, BigQuery sandbox, no billing, for `crypto_ethereum` and `crypto_bitcoin`. Databento: the USD 125 sign-up credit only, never a card charge, with a USD 100 spending cap; credits expire six months after sign-up.
- **2026-10-26: the language plan.** The pilot (stages 0 to 3 and 10) stays on the current stack, and stage 7 finishes as specified. Between stages 7 and 8 comes a new stage: an executable Lean engine whose laws are proved on the running code, bit-identical to `mm` on the frozen corpus, with OCaml for untrusted plumbing; Parquet stays the data format (read through DuckDB's C API or Arrow) and SQLite the ledger. Then `mm` and the Python are deleted, and stage 8's generalization is written once, in Lean. Its criteria and a paper revision are drafted when stage 7 nears its exit. Feasibility diagnostic (tag `lean-bench-2026-10-26`): a performance-oriented Lean engine, `fastmm`, ran W0 in 33.3 ms (`mm` 16.0, the Lean reference 660) and matched `mm` bit for bit on all 3,372 corpus runs. For the stage's criteria: the fast code is unproved, so laws need a refinement proof against the reference or a standing differential; bit-identity needs no fused multiply-add and `mm`'s libm; in-place array updates silently become copies when an array is shared, so the criteria should bound speed as well as correctness.
- **2026-10-28: erasure is blocker-class** (Python had grown 2,869 lines and shrunk 907 in three days). Two passes first: the Jobs migration ending net-negative in Python lines (baseline 12,350), and an erasure pass between stage 2's exit and stage 3's freeze over every module stage 3 freezes, from a deletion list by a reviewer who did not write the code, proven unchanged by the test-7 machinery. Both are done (12,365 to 12,333 lines; `audit/erasure/`). Then, right after stage 7 lands on `main`, a repo-wide pass under CLAUDE.md §2 over everything that survives the generalized kernel (code, specs, the paper, PROGRESS.md, CLAUDE.md, `ops/`, the runner scripts in `data/tmp/`, whose chain scripts collapse into one tracked, generic, resumable runner), with the corpus differential as safety net and a fresh-context Opus reviewer. Folded in: misplaced scripts (`audit/stage6/effort.py`) and criterion- or version-named files; PROGRESS.md citations in runner-imported files (`criteria/`, the stage 0 `ingest` modules, `cli.py`); `oci-cli` into the flake and `duckdb` out of it; the Python line-count report; deletion of one-off scripts whose outputs are recorded.
- **2026-10-28: the homelab rules.** Nothing of ours outside the namespace (since the move, `moneymachine` and `moneymachine-live`), and no other process or log read.
- **Reverse:** each stands until the human changes it; this entry only moves the record.

## 2026-10-30 01:30 UTC (2026-10-29 21:30 EDT): correction to the entry of 2026-10-28 14:14 UTC (10:14 EDT): whose windows pacing reads

- Since the move, `wait_for_room` runs in the series pod with the Cornell account's token (`CLUSTER.md` section 3), so it reads and paces the Cornell account's windows, which the cluster's sandboxed sessions spend. Sessions on this PC run on the human's personal account (kevvinlei89@gmail.com) and no longer draw on that window; the human's 50 % stop for them applies to the personal account's seven-day window. Which account the entry's 0.90 reading was taken on is not recorded. At the sandbox gate the Cornell seven-day window read 0.92, resetting 2026-11-01 05:00 UTC (01:00 EDT) (`audit/cluster/gate-unmasked.json`).

## 2026-10-30 17:30 UTC (13:30 EDT): GPT may build; the personal account's cap is gone (human)

- GPT as a builder has a Claude builder's access (`opencode run --auto` in the repo or a worktree). The isolated directory and its denials now apply only to its independent checks, whose results depend on them. The model that built a piece never gives its independent review, and GPT does not build what a frozen criterion has it check independently. No false-discovery or leakage outcome changes: frozen criteria and independent checks are as they were. Reverse by restoring CLAUDE.md's previous GPT section.
- The 50 % stop on the personal account's seven-day window is withdrawn. Reverse by restoring the line in PROGRESS.md's Budget.

## 2026-10-30 18:50 UTC (14:50 EDT): CLAUDE.md's section 3 rewritten for an active human (human)

- The human reviewed CLAUDE.md as outdated: they are usually present, the advisor chooses each builder's model, Lean and OCaml are where the stack ends, and the hard limits section goes. Sections 1 and 2 stay byte for byte, by their instruction.
- A fresh Opus session reviewed it with the whole repo and drafted the replacement. GPT's review stopped at its usage limit before any finding, so it is queued for its reset, about 21:20 UTC (17:20 EDT).
- Added beyond the notes, from that review: frozen identities are exempt from erasure, the holdout rule covers embargo and forward-window recordings as `audit/criteria.md` already does, and procedure defects are fixed only by the human as the paper says. These state existing rules; none loosens one.
- New advisor rules from the human: consult a fresh Claude session and GPT before a decision, and name prior art when an idea is already well covered.
- Reverse with `git revert` of this commit, keeping the C8.7 clarification, which stays true either way.

## 2026-10-30 19:10 UTC (15:10 EDT): the forward window stays protected by rule, not a lock (advisor, by the human's delegation)

- The frozen integrity-only rule for recordings of [2026-11-01, 2027-01-31) stands, and CLAUDE.md now states it. No technical lock is added: recordings sit on the cluster, in the mirror and in `data/live-oci`, and sessions here share a user with the mirror, so a real lock needs encryption or a second user. Research agents are already sandboxed from them. The window only confirms a stage 3 promotion, and it does not block stage 3.
- GPT's view is queued with its CLAUDE.md review; it was at its usage limit. Reverse by adding the lock before anything reads those recordings beyond integrity.
- Also: paper section 6 and the roadmap now state the language plan of 2026-10-26, which the paper had simply not caught up with (human, 2026-10-30). The Lean stage's criteria stay due when stage 7 nears its exit. Reverse with `git revert`.
- Also: `mm-oci-pull` and `mm-diskguard` use OnCalendar. OnUnitActiveSec left them with no next run from 2026-10-30 04:31 UTC (00:31 EDT), with last-pull stale until they were run by hand at 18:47 UTC (14:47 EDT).

## 2026-10-30 19:15 UTC (15:15 EDT): the two criteria tests that report recorded failures are strict xfails (human)

- **What:** `criteria/test_stage0.py::test_c07_execution_model` (C0.7, qualified) and `criteria/test_stage2.py::test_c26_power_amended` (C2.6, waived) are `xfail(strict=True, raises=AssertionError)`, each reason naming its record. `audit/criteria.md` is untouched and neither criterion's result changes: both stay failed, as the record says, and the assertions are the same.
- **Why:** a suite that always shows two failures hides a third. `strict` fails the suite if either test ever passes, so the evidence cannot change unnoticed, and `raises` keeps a missing or malformed evidence file a failure.
- **Said:** the human directed it; no reviewer asked. It cannot change a false-discovery or leakage outcome.
- **Reverse:** delete the two markers.

## 2026-10-30 19:15 UTC (15:15 EDT): the witness reads as_of once (human)

- **What:** `ingest/witness.py` takes each step's view from one `as_of(HOLDOUT_START, version)` with `knownAt <= t_d`, instead of calling `as_of(t_d, version)` twice per step. C1.4's check is otherwise unchanged. Trace sha256 and worst value identical; the argument and evidence are in `audit/stage1/witness-equivalence.md`.
- **Why:** 162 of 184 profiled seconds were those calls; C1.4's test took about 3 minutes, now about 1 s.
- **Said:** the human directed it, with this equivalence as its condition; no reviewer asked.
- **Reverse:** `git revert 1f15657`.

## 2026-10-30 19:43 UTC (19:43 EDT): stage 8's debugging rule tightens, and the terms objection becomes a known limitation (human)

- Accepted from `audit/stage8/manifest-revision-draft-2026-10-30.md` (B5): before a source's annex, integrity views only; after it, schemas, counts, hashes and test results; row samples only from agent-readable sources and search periods, each logged; none from kernel-only sources. This replaces the 2026-10-26 allowance once the revision is adopted. Reverse by restoring that allowance.
- Accepted (B3/B4): GPT's objection, raised three times, that the human's reading of the CME and Nasdaq terms may be wrong is recorded as a known limitation, not a further gate. It cannot change a false-discovery or leakage outcome; it remains a licensing risk the human knowingly takes, and the reading is not thereby shown correct.
- GPT's review of the draft is still queued; the revision is adopted into `scope-manifest.md` after it, under the manifest's own rule. A review finding on either point returns to the human.
- Correction, 2026-10-30 19:46 UTC (15:46 EDT): the heading above gives the Eastern time as 19:43 EDT; the entry was written at 19:43 UTC (15:43 EDT).

## 2026-10-31 00:00 UTC (20:00 EDT): four decisions after GPT's and Opus's reviews (human)

Reviews: `audit/reviews/2026-10-30-*`. The human accepted the advisor's recommendation on each.

1. **Forward window:** no technical lock, against GPT's recommendation. A real lock needs a second identity or separately held keys across three locations, and the prices are public. The integrity-only rule stands, and it binds every session, since the mirror on this PC still holds the cluster's recording. From 2026-11-01 00:00 UTC (2026-10-31 20:00 EDT), `mm-oci-pull` stops copying Hyperliquid recordings for the window to this PC. Reverse by adding the lock, or restoring the pull, before anything reads those recordings beyond integrity.
2. **Clock record:** GPT's node-native chrony record and revision text, not the `adjtimex` log a fresh Opus session advised. The homelab side is drafted for the human to run.
3. **Stage 8:** the manifest revision is adopted with GPT's corrections, including its wording that deleting restricted artifacts never removes campaigns or outcomes from statistical accounting.
4. **`agent-real`:** dated revisions, each reviewed by GPT before any run: arm A with zero evaluations is a void attempt (no claim, no arm B, a fresh campaign id); C3.3's "complete" means ended under One attempt; a missing or aborted finalist counts as p = 1 within its family; diagnostics are released only after the committed promotion decisions; holdout mechanism evidence comes from a later reporting step on the spent holdout; with zero finalists there is no claim, the holdout stays unspent, and the report says so. No kernel change. The running series stays on its image. Reverse any of these by a further dated revision before the run.

## 2026-10-31 00:05 UTC (2026-10-30 20:05 EDT): stage 8's manifest revision adopted, with a known limitation (advisor, on the human's decision of 2026-10-31 00:00 UTC)

- **What:** `audit/stage8/scope-manifest.md` gained the dated revision of 2026-10-31 00:05 UTC, the draft of 2026-10-30 with GPT's corrections (`audit/reviews/2026-10-30-gpt-stage8-draft.md`): the ECB chronology assurance replaced by chronology for those two rules only; coverage stated source- and operation-specifically; the added line that schemas, counts, hashes and test results are disclosures with no debugging exception. No class is admitted and every existing blocker stays. The draft file is deleted (git holds it, `e361ecf`).
- **Known limitation (replaces the draft's entry, which claimed statistical immunity and result deletion):** The human accepts this licensing uncertainty (CME and Nasdaq-originated terms on "metadata" and "generating output"); that acceptance establishes neither the interpretation's correctness nor information-boundary safety. All existing disclosure, reconstruction-test and C8.6 requirements remain unchanged. Required deletion of restricted artifacts does not authorize omitting campaigns or outcomes from statistical accounting, reducing the tested family, resetting selection history, or reusing spent evidence. If legally permissible audit evidence cannot be retained, the affected claims are reported as unverifiable or withdrawn, not silently removed or replaced as fresh attempts.
- **Said:** GPT, as above; the human accepted its corrections including the deletion wording.
- **Reverse:** a further dated revision of the manifest; the limitation entry only by the human.
