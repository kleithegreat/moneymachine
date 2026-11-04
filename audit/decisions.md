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
2026-10-31: L5_text revision (total `Json.Value.mentions`, `uniqueKeys` guard in `check`) frozen after GPT's independent FREEZE (`audit/stage7/l5-text-review-gpt-2026-10-31.md`), stage7-l5 merged into stage7; reverse by reverting the merge commit.
2026-11-01 10:41 UTC (05:41 EST), stage 7 port plan B1: the bars role drops `openTime` (SOURCES.md §6 dated revision, `hl-bars-4h` 2, `source::ROLES`, the annex row), the frozen Lean's `Registry.valid` and `barRow` being the simpler contract its laws are proved on; not judged (no judged run reads a declaration yet); reverse by restoring `hl-bars-4h` 1 in `sources/registry.json` and the role row.

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

## 2026-10-31 00:10 UTC (2026-10-30 20:10 EDT): three test guards tightened; correction to the 2026-10-30 19:15 UTC (15:15 EDT) entry on the two xfails (advisor, from GPT's review `audit/reviews/2026-10-30-gpt-witness-tests-clock.md`, findings 2 and 3)

- **Correction:** the entry's claim that `raises=AssertionError` keeps a missing evidence file a failure was false: `criteria/evidence.py`'s `load` skipped a missing file. It now fails for every stage already exited and skips only under `audit/stage3/` and `audit/stage4/`, whose evidence is not produced yet. `judged_ingest` likewise fails, not skips, when stage 0's second fetch is absent.
- **xfails narrowed:** `test_c07_execution_model` and `test_c26_power_amended` now hold only the waived predicate (every listed cell within coverage and cost; power >= 0.30). Evidence presence, sample counts, the exact set of recorded failing cells (BTC:sell:1000, SUI:sell:10000, kPEPE:sell:10000) and the campaign counts and recorded power 0.05 are ordinary passing tests, so a new failing cell or a wrong count fails the suite. `audit/criteria.md` and what the criteria judge are unchanged.
- **Mutants:** a mutant is `caught` only when the clean run passes and the mutated log shows the test failing by assertion (a panic in a Rust test file, or a failed pytest test with an AssertionError); a timeout, memory kill, collection or build error is `INCONCLUSIVE`. Rerun with the new rule: all 17 caught, none changed (the earlier logs also classify as caught).
- **Said:** GPT, findings 2 and 3; none of it changes a false-discovery or leakage outcome.
- **Reverse:** `git revert` the commit.

## 2026-10-31 00:08 UTC (2026-10-30 20:08 EDT): the clock record is the five-line kernel read, and process follows one question (human)

- Reverses item 2 of the entry at 2026-10-31 00:00 UTC (2026-10-30 20:00 EDT), which the advisor had recommended. Only C5.3's 72 h segment depends on the record, its 1 s figure is reported rather than judged, and there is no deadline, so an Ansible role and a typed offset/bound model outweighed the need. GPT's objection stands as a known limitation: the kernel's figure is the daemon's own bound and does not prove freshness. The withdrawn text stays in `audit/criteria.md` beneath a dated revision. The Homelab was not touched. Reverse by a further dated revision, using GPT's text.
- CLAUDE.md: one question sets the process (could this change a judged result, or can't it be undone?), one review round by default, findings name the outcome they could change, no review rounds for inactive work, and rules name the failure they prevent. Why: the human, seeing agents build permits and ledgers instead of food. Reverse with `git revert`.

## 2026-10-31 (2026-10-30 EDT): the cluster's clock acceptance in `audit/cluster/handoff.md` does not stand

- The handoff's "about 5 ms" clock agreement, from Hyperliquid L2 medians, is not accepted as a clock check, per `audit/reviews/2026-10-30-gpt-witness-tests-clock.md`. The cluster's record is the kernel bound of the entry above (`CLUSTER.md`, Clocks). `handoff.md` is untouched. Reverse by a further entry.

## 2026-10-31 (2026-10-30 EDT): the sources poll target is 240 s (advisor)

- C5.3's hosts revision covers an interval only between polls at most 5 minutes apart; a 300 s target missed that on jitter alone (287 of 575 gaps over 300 s). `POLL` is 240 s (Discourse and Snapshot allow 100 or more requests a minute, `venue/sources.toml`). Deployed with the kernel clock record, the 72 h segment having just begun. Reverse by setting `POLL` back to 300.

## 2026-10-31 00:22 UTC (2026-10-30 20:22 EDT): three rules for `agent-real` (human)

- From the fresh Claude review of its revisions (`audit/reviews/2026-10-31-claude-agent-real-revisions.md`), recorded in `audit/criteria.md`. GPT's review is queued before any run.
- An attempt stopped from outside is not void and goes to the human; only a session that reached its own end can be void. It closes a repeatable stop with public prices in view. Because the code cannot tell an operator's stop from a dead pod, a dead pod goes to the human too.
- A failed audit or a changed input blocks the release and goes to the human, with no further arm A attempt (the "complete" revision, as committed).
- With zero finalists, stage 3 can exit with the release items empty, stating that the release path was not exercised.
- This PC's claim line stays even if the holdout ends up unspent: the cluster's store can still release it, and removing the line would allow a second release. The mechanism reporting step gets no code until arm A has finalists.
- Reverse any of these by a further dated revision before the run.

## 2026-10-31 04:50 UTC (00:50 EDT): C3.2 v1 failed; v2 on 20 fresh ids (human)

- What: the series' 20 campaigns `agent-null-N2-0..19` all crashed at 2026-10-31 04:00 UTC (00:00 EDT), in 0 s and before any model call, because N2's funding reads `data/store` and the series pod mounts only `agent`. Under C3.2 each crash counts as a promotion, so C3.2 v1 failed as written (20 of 20). Its log (`mirror/agent/agent-null.jsonl`) stays the record of that failure. A new version runs 20 fresh ids with the funding delivered by its frozen sha256, as batch Jobs already do, and is judged on those ids alone, under a dated C3.2 revision committed before it starts. The crash rule is unchanged.
- Why: the defect is in delivery, not in arm A's procedure or harness (no hashed file changes); fresh ids give fresh null markets and keep v1's failure on record.
- Reviewers, each without the advisor's plan: a fresh Claude (`audit/reviews/2026-10-31-claude-c32-crash.md`) and GPT (`audit/reviews/2026-10-31-gpt-c32-crash.md`) agree on cause and fix; they add one series-log definition for pacing and the real campaign's lock, a check before the first id, a start marker before generation, and binding `check_ready` to v2's cohort. GPT's permanent `FIRST_NEED` floor on pacing is not adopted (it would stall the series on the seven-day window); rows with no model call are kept out of the measurement instead.
- Reverse: none for v1's failure. v2 can be abandoned before it starts by not committing its revision.

## 2026-10-31 06:15 UTC (02:15 EDT): C3.2 v2's code choices (builder: C3.2 v2)

- Pacing: `need` ignores a campaign whose usage shows no tokens, since it measured nothing (v1's 20 rows taught 0.01). No `FIRST_NEED` floor on measured needs: it would hold every start to 0.3 of the seven-day window. Reverse: drop that condition in `need`.
- `Store.as_of` raises on a dataset with no revisions instead of returning None, which every caller used at once; a missing store now fails where it is read.
- `agent-real` also requires the C3.2 summary's kernels to be exactly its own `mm` (C3.3's unchanged kernel), beside v2's declared ids and at most 2 promotions.

## 2026-10-31 06:45 UTC (02:45 EDT): `agent-real` before its run, from GPT's review (`audit/reviews/2026-10-31-gpt-c32-v2-agent-real.md`, section 2 finding 2, section 3) (builder: agent-real findings)

- C3.1 covers every arm A run, null and real: the C3.2 summary carries each campaign's audit, and `agent-real` starts only if every one of v2's 20 is recorded and holds. A crashed row has no audit and the code cannot tell whether its session ran, so it blocks and goes to the human. Reverse: drop the audit check in `check_ready`.
- A zero-evaluation arm A is void only after a designed end (a clean exit, the turn limit or the wall time); any other end (a nonzero exit, a signal, no run record) may be an outside stop and goes to the human. Stricter than the criterion's list, which counts a provider refusal as the session's own end: one that exits nonzero goes to the human too, since the code cannot tell it from a stop such as a cut network. Reverse: void on `stopped == "finished"` with any exit.
- The dataset version and the holdout start join `inputs.json`, written once before arm A; a resume with either changed is refused. Reverse: drop them from the receipt.
- On resume `run.json` is reconciled with the ledger's run disclosure: disclosed if missing, refused if different. Reverse: return the file without the ledger check.

## 2026-10-31 23:12 UTC (19:12 EDT): the Write denial, decided by the advisor (the human: "these should have been autonomous decisions"; CLAUDE.md's Decisions section now gives a reviewed decision to the advisor)

Evidence `audit/stage3/write-denied-2026-10-31.md`; reviews `audit/reviews/2026-10-31-{gpt,claude}-write-denied.md` (consults, independent, agreeing on the fix) and `audit/reviews/2026-10-31-gpt-harness-fix{,-2}.md` (two rounds on the candidate, every finding fixed).

- **The fix is adopted:** branch `harness-fix` (`789834e`): the sandbox allows `Edit(//work/**)`, which is what permits the Write tool, in place of the inert `Write(//work/**)`; a real-session canary in the exact sandbox runs before each freeze and each session (series, thesis, agent-real's arm A), and a failure starts and counts nothing; `freeze_harness` refuses only once a campaign of a declared cohort or the current real attempt started. Reverse: revert the merge and refreeze.
- **C3.2 v2 is not a pass.** Its 20 runs made no evaluation (1 counted, by the no-daemon-call rule): the frozen procedure, whose tools include Write in the workspace (`audit/criteria.md`, harness), was never established. Its record stays; no report states C3.2 met by v2. Reverse: none.
- **C3.2 v3** on fresh ids `agent-null-3-N2-0` to `-19` under a dated revision, with one tightening both reviewers allow for a new version: a campaign with no evaluation counts as a promotion (it cannot increase false discoveries). C3.3's lock moves to v3. Reverse: abandon v3 before its first campaign by not committing its revision.
- **C3.1's audit rule is unchanged** (denials are recorded, not failing): the per-session canary is the contract check, and an agent's refused non-client command is expected behavior. Reverse: a revision making a denied Read or Write in /work fail the audit.
- **Stage 10 refreezes** on the fixed sandbox, bundling PROGRESS's queued refreeze items; C10.5's window restarts at the new freeze (the 10-28 precedent). No agent registration accrued under `thesis-62476ec60a1b`, so nothing is lost. Reverse: none once the new track runs.
- **Roll** only `thesis` and the series Job to the new image; `sources` stays until after 2026-11-03 00:18 UTC (2026-11-02 19:18 EST), C5.3's segment.

## 2026-11-01 03:46 UTC (2026-10-31 23:46 EDT): stage 10 refreezes now, with the retrieval and runner fixes (advisor)

- **What:** `thesis-ca16df8d8d6d` is replaced by a new track version frozen now. Its main sessions could not read: since the move to the cluster every fetch was refused (27 of 27; on this PC 22 of 24 succeeded), because the image has no system CA store and robots.txt failed TLS, and an http robots.txt's 301 read as disallow-all. Fixed: HTTPS verifies against certifi's pinned bundle (declared in the flake); robots.txt follows same-host redirects; a robots 429 fails closed; session directories per version (a refreeze after a day's sessions re-ran that day into the old directory); a session that raises records its end with the error; a stop during the snapshot or an expired day starts nothing; the pod gate fetches each certified retrieval entry through the fetcher.
- **Why:** these fixes are behavior-affecting and fork the track whenever they land; under the old version the main arm is a no-reading arm, so its days cannot test the main-versus-no-reading comparison. C10.5's window restarts at this freeze; earlier versions are never pooled, and C10.6 lists `thesis-62476ec60a1b` and `thesis-ca16df8d8d6d` as run with retrieval broken (the latter with an unended 10-31 start), not by forecast performance.
- **Said:** a fresh Claude (`audit/reviews/2026-11-01-claude-thesis-bundle.md`) and GPT (`audit/reviews/2026-11-01-gpt-thesis-bundle.md`) both: refreeze now; GPT's four findings and Claude's certifi finding fixed before the freeze. Integrity-only inspection: ledger counts, call outcomes and refusal reasons, no forecast or content.
- **Reverse:** none once the new version runs; a later version can follow.

## 2026-11-01 05:13 UTC (2026-11-01 01:13 EDT): the night's two decisions stand (the human delegated their review to the advisor's judgement)

- The human: "proceed with your best judgement for the two decisions". Both stand as decided: the Write denial (2026-10-31 23:12 UTC (19:12 EDT); C3.2 v3's campaigns now evaluate, 6 to 11 each, audits holding) and stage 10's second refreeze (2026-11-01 03:46 UTC (2026-10-31 23:46 EDT); retrieval fetches certified documents from a pod on the new image). Each had a fresh Claude and GPT review with every finding fixed. Reverse: as each entry states.
- Also: the workstation's stale `desktop` node (NotReady since 2026-10-29 02:03 UTC (2026-10-28 22:03 EDT), when k3s stopped at a reboot without `ops/jobs.py` leave) paged Alertmanager every 4 h (179 Discord notifications); the human deleted it. Stopping k3s on the desktop now deletes its node (dotfiles `efb606b`, switched with the human's leave), and `jobs.leave` drops its own delete (`82eba31`). Reverse: revert both.

## 2026-11-01 06:42 UTC (2026-11-01 01:43 EST): stage 3's real campaign runs (advisor; the human asleep, "act autonomously")

- **What:** `agent-real` on image `sha256:1cd091eb…` (`119afd3`), dataset version 1792613363942, report from 1785542400000 (2026-08-01), attempt `stage3-real`: seed the store and holdout, then the claim line, then apply (`CLUSTER.md` §2). It spends stage 3's holdout once.
- **Why:** C3.1 and C3.2 hold (`audit/stage3/null-summary.json`, `119afd3`: v3, 0 of 20 counted, every audit holding, one kernel); C3.3's order is C3.1 → C3.2 → freeze → both arms.
- **Checked first (integrity only):** the pod gate on the digest (`audit/cluster/gate-unmasked.json`: harness `6a335714…` equals the frozen one, sandbox tests pass, a session answers, only the model API reachable); the store's policy identical to `policy.json`; every holdout file hashed and matching its record (`audit/holdout.json` for bars and funding; stage 5's lineage for the two event datasets, which no strategy can reference: the search store carries none, C5.6); no prior attempt, claim or `real/` here or in the agent volume; the series complete.
- **Said:** a fresh Claude and GPT, both GO AFTER their checks, all done (`audit/reviews/2026-11-01-{claude,gpt}-agent-real-preflight.md`). An outside stop goes to the human; only a qualifying void advances the id.
- **Reverse:** none: the holdout is spent once claimed.

## 2026-11-01 10:27 UTC (05:27 EST): C4.5 v1 failed; its series stopped between campaigns (advisor)

- **What:** the swarm series' first two campaigns, `swarm-null-N2-0` and `-1`, made 33 and 36 evaluations across 4 agents each, under C4.5's 200, so each counts as a promotion: 2 > 1, C4.5 failed as written (log sha256 `ad79ecd0…` from the mirror, checked against MANIFEST: `audit/stage4/null-v1.jsonl`, `null-summary-v1.json`). No crash; cross-agent history reached in both.
- **Stopped:** the Job deleted at 10:26 UTC (05:26 EST) while it waited between campaigns, so nothing was interrupted; 8 ids never started. Stopping cannot change the verdict, and a further version needs fresh ids.
- **Why it failed:** the agents stop early by their own choice (as stage 3's did: 6 to 22 each), while the 200-evaluation floor assumed a swarm uses most of its 400. The floor was meant to catch a broken swarm; it now also counts working ones. A C4.5 v2 needs that re-derived, reviewed, under a dated revision with fresh ids.
- **Reverse:** none for v1's failure.

## 2026-11-01 16:15 UTC (11:15 EST): C4.5 v2 authorized (human)

- **What:** the human: "authorize c45 v2, go ahead". C4.5's 200-evaluation floor is removed by the revision committed alone as `criteria: stage 4` (`4531257`): ten fresh campaigns `swarm-null-2-N2-0` to `-9`; one counts if it promotes, crashes, or any of its four agents makes no evaluation; pass with at most 1 counted. Branch `c45-v2` merged; `agent-series` applied on a new image.
- **Why:** the floor measured search effort, which the procedure never required, and counted working swarms that stop by choice (v1: 33 and 36 evaluations).
- **Said:** a fresh Claude and GPT both advised deleting the floor with brief and harness unchanged (`audit/reviews/2026-11-01-{claude,gpt}-c45-v2.md`); GPT's per-agent zero-evaluation rule adopted.
- **Reverse:** none once a v2 campaign starts; a later version needs fresh ids. v1's failure stands.

## 2026-11-01 16:51 UTC (11:51 EST): series pacing measures a campaign's need from any account (advisor)

- Campaigns start under the same 0.8 ceiling, but a campaign measured on one account now sets the expected need on every account (they share one plan), so TAMU runs swarm campaigns too instead of one per Cornell window (`efb3f7d`); applied between campaigns, 1 of 10 recorded. It cannot change a verdict except by a crash, which the ceiling guards as before. Reverse: restore the per-account `need`.

## 2026-11-01 16:59 UTC (11:59 EST): stage 7's B2 is settled by revising the frozen Lean (advisor)

- **What:** a dependency spans several sources, as SOURCES.md §5 (`d1d7ad8`) and the C7.4 annex already declare and the Rust already holds; the Lean's single-source `Dep` (`2790140`) narrowed that without a recorded decision. The dated revision, on branch `stage7`: `Dep.sources`; upstream keys `(source, stored entity, event)`, the source one of its dependency's; an upstream key without a usable knownAt makes the row unusable (`mapM`, not `filterMap`), an empty lineage staying unusable; evidence revisions have `coin = none` and are reached only as upstream keys; an evidence declaration names its event column, the recorder-trusted observation time (`observed`, `recv`), and lists every key column (`entityColumns`); lineage's per-revision `fetchedAt` goes; SOURCES.md §5's "selected at that version" becomes the bitemporal bound. `L8_known` and `L8_monotone` restated and re-proved; every law whose referenced definitions change is named and reviewed (C7.7), then refrozen. B3's suite is drafted after, so it freezes once. Both "Evidence keys" points are settled this way: controls as `source.rs` computes them, keys by stored entity rather than an index.
- **Why:** under the frozen Lean a covered zero count is never delivered (C7.4 fails as written); every restatement of the feeds either keeps that or drops sightings from the knownAt bound (leakage, named test 13).
- **Said:** GPT (`audit/stage7/b2-review-gpt.md`) and a fresh Claude (`audit/stage7/b2-review-claude.md`), consulted separately: both option (a). Adopted from Claude: stored-entity keys (an index would renumber), the resolver-level unusable rule (GPT left it to the verifier or the resolver). Adopted from GPT: review every law whose definition closure changes, not only L8.
- **Reverse:** before the refreeze, drop the branch's revision; after, a further dated revision. No judged stage 7 evidence exists yet.

## 2026-11-01 20:30 UTC (15:30 EST): B2's draft is not frozen; its reviews' findings ruled on (advisor)

- **Fix before the freeze:** (1) Opus B-1: a retraction recorded by the derived revision bounds it; drop the retraction filter from `upKnown` and L8_known's premise (leakage, test 13; it can only make rows later), confirmed against `Resolve.lean`. (2) Opus B-2: unique dependency names in a row's lineage in `Trusted.canonical`, so `find?` cannot hide a key, confirmed. (3) GPT B1: `Registry.valid` rejects an empty `Dep.sources`, with a negative differential case. Opus would leave it for the formally stronger theorem; the spec and `mm` say one or more, and one clause ends a disagreement a run can observe. (4) GPT B2 and Opus's stale lines: a dated SOURCES.md revision for event tie order, tombstones and rejected revisions, the required set, extra columns, authorization order, and §1's and §2's keys.
- **With them:** stored-entity encoding injective and pinned (N-2, GPT); no exact duplicate sightings in the annex (N-3); the injective stored-entity mapping stated in the general contract; an evidence key with several columns in the differential; superseding notes appended to `laws-v2-draft.md`'s audit table.
- **Recorded as limitations, no change:** `differs` ignoring lineage can lose a row whose first revision was unusable (N-1): missingness only, and comparing lineage would turn recomputations into corrections, which undefine events. Lineage completeness and a recorder-set event column stay with C7.3's verifier, each to get its test there.
- **Said:** `audit/stage7/b2-revision-review-{gpt,claude}.md`. Both found the resolver design sound and no weakened law; the two blocking sets did not overlap.
- **Next:** one more round, on the fixes' diff only, since `L8_known` changes; then the freeze. **Reverse:** drop the draft; nothing is frozen.

## 2026-11-02 00:57 UTC (2026-11-01 19:57 EST): B2's revision of the frozen Lean is frozen (advisor)

- **What:** frozen on `stage7` at 00:55 UTC (2026-11-01 19:55 EST) (`7997257`, `audit/stage7/laws-frozen.md`); the proofs re-checked after it (`audit/stage7/proof-validation-b2.md`). The only statements changed are `L8_known` and `L8_monotone`; every other law was reviewed for its changed closure.
- **Why:** the rulings of 2026-11-01 20:30 UTC (15:30 EST) are all fixed (`4a6a6d4`), and the reviews of the fixes' diff found no blocker. The retraction change moves no migrated evidence: every one of the 162,031 sighting and 4,526 poll keys has one revision and no tombstone exists (a builder's read-only counts, not recomputed by the reviewers; recordings after 10-29 fall after C7.4's cut and were not counted).
- **Said:** GPT and a fresh Opus, consulted separately (`audit/stage7/b2-fixes-review-{gpt,claude}.md`): both FREEZE. Applied with the freeze: Opus's F-3 (a stale Preflight clause) and cosmetic notes, comments and prose only. Carried: F-1 and F-2 (the response to a repeated lineage name; one tuple under two encodings) to B3 and slice 5; tests of lineage completeness and a recorder-set event column to C7.3's policy. GPT's qualifications noted: a raised bound can also mean missingness, not only a later row; N-1 can change definedness, and any C7.4 mismatch from it still fails migration.
- **Reverse:** a further dated revision; no judged stage 7 evidence exists yet. Also on the record: `ops/builder.sh` runs builders in a capped scope with a real stop (`4eab665`) after an uncapped differential and a hand-set cap cost the fixes builder 80 minutes.

## 2026-11-02 01:32 UTC (2026-11-01 20:32 EST): B3's draft suite is not frozen; its reviews' findings ruled on (advisor)

- **Said:** `audit/stage7/b3-review-{gpt,claude}.md` on `stage7`: both found every expected result right and both block the freeze, largely on different bugs the suite would pass.
- **The spec, one dated revision of RULES.md §6 and §7, recorded in `laws-frozen.md` with RULES.md's new hash (no Lean changes):** undecodable stored bytes make the dataset invalid, for eligible revisions only, and `R_ROW` is never a resolver result. A lineage is read whole, every member shape-checked; a key naming an undeclared source is invalid. A well-shaped key of a source outside its dependency, or with no delivery, is unusable, never malformed. A member naming no declared dependency is not resolved. An integer and a non-integer number differ even when numerically equal; a slot decodes if and only if it is an integer; nested cells are invalid; reserved column names are named; `num` is defined. The retraction rule is restated whole so it can be read without its history. The case format moves to §7, with no reference to the Lean: GPT's independent resolver gets RULES.md, SOURCES.md and §7, never the suite.
- **The suite:** hand cases where the raise to the replaced revision's knownAt does the work, for a correction and for a rejected later evaluation (Opus B-1); where the derivation bound decides a later derived revision, with an upstream known after its fetchedAt (B-2; GPT's clamping bug); a slot unlike the event time, moved by a correction, then retracted (B-3); roles in the format, with hand cases; declaration order against dependency order; one evidence tuple under two encodings; mixed numerics; malformed lineage and a non-integer event. Entries compare the delivered values too, or a resolver could attach the final revision's values to every delivery. Keys compare in a canonical order. The generator draws its registry shape, lags, slots and upstream rules, with coverage assertions; pairs count only stores that resolve, with a floor on keys of at least two revisions. Case 44 is corrected.
- **C7.6 gets a dated revision before anything is judged, committed alone before the suite's freeze.** Its bullet demands the latest revision chosen before availability, which the human's bitemporal decision of 2026-10-26 removed. It loosens nothing: at least 1,000 pairs, exact match, GPT from the spec alone, and the actual Rust loader all stand; Lean is added. Version 1's results do not count. Holdout staging, evidence never delivered, and the one-coin check are named loader-level tests, since a timeline can't show them.
- **The swap:** the freeze commit replaces the suite files and size check; the old resolvers die in slice 5 with their callers; `test_three_implementations.py`'s shallow `same` is replaced; `refmm`'s resolver mode decodes the case texts itself.
- **Next:** one more round on the fixes, including C7.6's revision text, since these change the format and the spec. **Reverse:** nothing is frozen.

## 2026-11-02 01:44 UTC (2026-11-01 20:44 EST): no stage 8 data purchase, indefinitely; agent memory is a research question (human)

- **What:** the human: "stage 8 data purchase will be no indefinitely. whether agents get memory should be a research question". Norgate and Massive are not bought, so equities and index constituents stay blocked, as `audit/stage8/scope-manifest.md` already records them; Databento stays within its sign-up credit. Stage 8's criteria already provide for this: completion is reported for the admitted scope, with its tier, so nothing is revised. Agents get no memory across campaigns unless a pre-registered study supports it.
- **Reverse:** the human's, at any time.

## 2026-11-02 02:53 UTC (2026-11-01 21:53 EST): C4.5 v2 campaign `swarm-null-2-N2-5` counts; the series runs on unchanged (advisor)

- **What:** its agent A4 made no evaluation, so it counts under v2's rule: 1 counted of 6 recorded, and a second fails v2. Nothing promoted; its other three agents made 11, 9 and 9; audits hold.
- **Why it happened:** the frozen permission is `Bash(./mm-agent:*)`, as the brief writes it. A4 alone of 24 agents ran `/work/mm-agent`, was denied five times (one try set `dangerouslyDisableSandbox`; denied too), wrote three strategies it could not test, and ended asking for input no headless session gets. The permission worked as frozen, so this is agent behavior, not a broken harness.
- **Decision:** no change. Changing the permission or the brief forks the harness, and replacing or stopping campaigns after seeing this one is what v2 forbids. If a second campaign counts, v2 fails as written, and any v3 is a labeled new version on fresh ids. Reverse: none needed; nothing changed.

## 2026-11-02 03:44 UTC (2026-11-01 22:44 EST): C4.5 v3, a contingency written before v2 ends; a crash no longer loses the gate decision (human, on the advisor's text)

- **Contingency, not a revision.** v2 is judged as written and keeps running. If v2 passes, this lapses unused. If v2 fails, this text goes to the human for the go, then is committed alone as `criteria: stage 4` before any campaign. It is fixed now so that how v2 ends cannot shape it, and it was informed by a fresh Claude and GPT (`audit/reviews/2026-11-02-{claude,gpt}-c45-v3.md`); it removes v2's zero-evaluation count, which is the human's to loosen.
- **v3:** ten fixed campaigns `swarm-null-3-N2-0` to `-9` on the unchanged harness, briefs, kernel, N2 and gate; every started campaign counts, with no replacement, padding or retry. **Promoted:** the gate promotes anything, whatever else happened. **Unresolved:** the gate or holdout decision did not complete; a ledger, audit or agent record is missing or mismatched; or a session that had received any disclosure crashed. **Established:** the gate completed over an audited ledger with at least one filled trial, at least two agents made an evaluation, and one received another's through `history` (C4.3). An agent that received nothing and made no evaluation, crashed or not, is reported, not counted. No evaluation floor. Code computes each class from the ledger, and missing evidence means unresolved. **Pass:** all ten recorded, promoted plus unresolved at most 1, and at most 1 campaign not established. **Failed:** promoted plus unresolved at least 2, reporting the two separately. **Not established:** anything else; no pass, no free retry, and a further version needs the human and fresh ids.
- **Reported, never judged:** finalists, SPA p-values, maximum DSR and screened counts beside H400's and C3.2 v3's runs; bankruptcies, aborts and denials by kind, sandbox overrides included; per-agent evaluations, history calls and stop causes; observed promotions pooled across versions with their exact bound. Two or more campaigns with finalists would be far outside the baselines' 0 of 300, and is stated as such. A pass is stated as a smoke test on the swarm's code paths: the error guarantee rests on the holdout test's assumptions, and a pass does not validate swarm error control or power.
- **The crash fix:** one agent's exception made the series record a crash without running the gate over the ledger (`gate/agent/campaigns.py`, outside `harness_hash`). `swarm_null` now runs the gate and records the crash beside its outcome; `cross_agent_history` and `audit_run` accept an agent that left no log or transcript. Under v2's rule such a campaign counts as before. **Not deployed:** `agent-series` stays on image `cce5a6f3…` while v2 runs. Reverse: revert the commit.

## 2026-11-02 05:46 UTC (2026-11-02 00:46 EST): C4.5 v3 needs no further go (human)

- The human: "if v2 fails go with v3 autonomously without my permission". This replaces the contingency's "goes to the human for the go" above and authorizes removing v2's zero-evaluation count if, and only if, v2 fails as written. On that failure the advisor records it, stops the series between campaigns, commits the contingency's text alone as `criteria: stage 4`, has the counting code independently reviewed, and starts `swarm-null-3-N2-0` to `-9`. If v2 passes, v3 lapses. Reverse: the human's, at any time before v3's first campaign.

## 2026-11-02 05:55 UTC (2026-11-02 00:55 EST): B3's fixes are not frozen; second round ruled on (advisor)

- **Said:** `audit/stage7/b3-fixes-review-{gpt,claude}.md` on `stage7`: both found every recomputed result right and the first round's bugs caught, and both block the freeze, on what the suite doesn't reach: the actual loader.
- **The decoding law moves to what the resolver reads (Opus B1, verified: `ingest/store.py`'s META are ordinary columns of typed Parquet):** metadata, declared columns as cells, and lineage. An undecodable declared cell, event column or lineage makes the dataset invalid; undeclared columns are never read. One mapping per representation: JSON texts in RULES.md §7, Parquet in SOURCES.md §2 (Int64 integer, finite Double non-integer, Utf8 string, Boolean boolean, null; nothing else decodes). The cases this flips go with it. The revision names what it replaces (R_ROW as a retraction; §1's no-floating-point sentence for stored cells) and says that where earlier text differs, it governs.
- **C7.6's revision names its participants:** the Python one is `store.as_of`'s bitemporal replacement, the frozen bullet's production path, never a test-only transcription, and the plan and README agree; `mm`'s loader runs the cases through the store's Parquet layout, by a stated path. **A named loader-level comparison (GPT's blocker):** actual observations against Lean's `resolveAll`, per delivery: values, role payloads, undefined on a retraction, slots, final flags; retraction CELLS are null. Lean's decoding layer is new code, one more implementation there, and `Ref/Json.lean`'s large-integer conversion is handled in that decoder.
- **Also before the freeze, since the text freezes:** the REACHED tags and classes both reviews show certify too little; a non-integer case separating binary64 from exact decimal; how results are read; the escape lost from the example; the size definition's one home in C7.6; the date. Self-checks stay labeled as such and aren't reproducible evidence.
- **The two-run checks (`rust-port-plan.md`) get GPT's qualification:** RULES.md's exceptions stand, so late final venue-state revisions and global admission refusal are carved out by name.
- **Next:** one more round on the diff, since the law changes. **Reverse:** nothing is frozen.

## 2026-11-02 06:18 UTC (2026-11-02 01:18 EST): GPT's bug hunt triaged; the thesis bundle goes first (advisor)

- **Said:** `audit/reviews/2026-11-02-gpt-hunt-{recorders,thesis,plumbing}.md`, static reading with no data. The advisor confirmed against the code: invalidation reads the next bar's open at the close's availability, which C10's rule forbids (`thesis/positions.py`); a missing-data status is written only after its deadline (`thesis/runner.py`); a datalayer body is written in place and then reused unchecked (`ingest/datalayer.py`); every four-hour verification batch is queued twice (`ingest/record.py`); the stage 4 evidence test omits the per-campaign audits (`criteria/test_stages3to5.py`). The rest are GPT's reading until a builder's test shows them.
- **The thesis bundle first, on its own branch, each finding shown by a failing test first:** every code fix forks the manifest and restarts C10.5's window, which is two days old, so waiting only raises the cost. It takes thesis findings 1 to 8 and recorders 1 and 2, which the manifest also hashes. Review on the diff (GPT and a fresh Opus), then a refreeze before the next day's sessions, if the review agrees. **Reverse:** drop the branch; nothing is frozen until then.
- **Next, no fork:** the audits in the stage 4 evidence test; a test pinning `kernel/DSL.md`, which agents read and `harness_hash` omits (unchanged since before the freeze, so no evidence is affected, and the hash itself waits for the next fork); a torn series log; verification reporting success with no manifest, the mirror's race, the Oracle pull's overwrite; the HL verification batch. **Recorded, no fix now, each needing a fork or the kernel:** the empty-file hang and selections' identity (daemon), one experiment identity naming two results (kernel, stage 7 checks it). **To stage 7:** a full page of sources admitted as complete coverage, since it can change event counts (C7.4). The stage 3 report's `distinct_canonical` counts equivalence classes, noted as a qualification of its label.

## 2026-11-02 07:56 UTC (02:56 EST): ops-fixes — stage 4 audit evidence guard

Five failing synthetic mutations reproduced acceptance of mismatched, forbidden-tool, missing-agent, missing-campaign and absent-agent audits. The existing stage 4 check now requires the declared campaigns and all four passing per-agent audits, without changing promotion counting or either recorded strict xfail. Independent test design was supplied from tests and requirements only; no live evidence was inspected. This implements the triaged guard, not a new criterion or a rejudgment. Reverse by reverting this fix; no frozen identity changes.

## 2026-11-02 08:09 UTC (03:09 EST): ops-fixes — remaining reproductions and commit blocker

- **DSL identity omission reproduced:** an in-memory mutation of `kernel/DSL.md` left `harness_hash` unchanged. The new test pins sha256 `8cfb48160a3cdc9e8d5ccb9ca12f04bf925e4cde4fe004e679485279bc28646b`; its first run against those simulated changed bytes failed, and it passes against the untouched file. Neither the DSL nor the harness changed; this is a guard, not a refreeze.
- **Series tail reproduced:** SIGKILL after partial JSON and partial UTF-8 writes blocked recovery; a complete final row without its newline concatenated with the recovery row. Under the existing exclusive lock, only an invalid unterminated final value is discarded; complete values are separated and retained. The started campaign becomes a counted crash, the next campaign proceeds, and a second restart is idempotent. Interior corruption remains an error, with history untouched.
- **Mirror findings reproduced:** each absent expected manifest, including an entirely empty mirror, previously verified successfully. Verification now refuses it. Publishing a body and its poll after enumeration also committed a dangling reference; the mirror now refuses that generation before replacing its manifest. The prior manifest remains usable over its recorded prefix, and the next complete copy succeeds. No recorder or frozen persistence code changed.
- **Oracle overwrite reproduced:** shorter, equal-length divergent and longer divergent sources all previously returned success. Pulls now transfer to a private staging directory, checksum even equal-metadata files, validate each existing destination as a prefix of its staged source, and only then atomically replace files. Unchanged files can be hard-linked into staging; no in-place rsync remains. A refusal preserves existing bytes and the last-good marker, reports to stderr and the existing blocker mechanism, and retains the forward-window exclusion. Tests substitute local rsync sources; no SSH or real host configuration was accessed.
- **HL batch findings reproduced:** failures at the first, fourth and last request discarded outstanding verification work; a four-hour boundary made 44 verification requests rather than 22. The queue now contains individual requests, removed only after success; one enqueue per boundary replaces the duplicate batch path. Successful requests are not retried after a later failure.
- **Budget checked, unchanged:** the rules list eleven non-delisted coins. Deployed total 480/min minus the reserved 120/min leaves 360; eleven funding plus eleven bar requests cost at least 22 × 20 = 440. The deficit is 80, requiring at least 560 total with that reservation, before retries or other overhead. The limiter therefore cannot fit the boundary into its 35-second completeness bound even after duplicate verification is removed. No budget, workload, image or deployment changed.
- **Checks and blocker:** the affected suites passed (76 passed, one skipped, four existing xfails). The required full-suite invocation fails because the clean worktree has no `data/store/policy.json` or funding revisions; Lean differential workers also failed/timed out. The request forbids accessing data or frozen files and requires tests to pass before every commit. An interactive clarification was unavailable, so no exclusions, workaround data or commits were made. All fixes remain uncommitted on `ops-fixes`; `PROGRESS.md` records the blocker. No finding was dismissed as unreproduced. An independent local-code review is pending. Reverse by removing the uncommitted fixes, without deleting this audit entry.

## 2026-11-02 08:12 UTC (03:12 EST): ops-fixes — review closed; final full-suite result

The independent review found one Oracle publication race: overlapping pulls could validate against the same old destination, then replace longer history with a shorter snapshot. A two-process regression reproduced it before the correction. The publisher now locks the destination across validation and replacement; both overlap and SIGKILL-before-replacement paths pass. The reviewer rechecked those changes and found the race resolved, with no further in-scope preservation defect. The final required full suite reports **395 passed, 2 failed, 2 skipped, 4 xfailed**: only the kernel witness test's absent `data/store/policy.json` and the Lean run differential's absent funding revisions fail. No workers crashed on this final run. All targeted regressions pass; no test was excluded or newly xfailed. Branch and protected-file checks confirm `ops-fixes` only, with no kernel, thesis-manifest or agent-harness hashed source changed. No commit was made because the full-suite gate is not met; no deployment or live access was attempted.

## 2026-11-02 08:25 UTC (03:25 EST): ops-fixes — append-only series recovery (builder, advisor ruling 1)

Following `audit/reviews/2026-11-02-claude-ops-fixes.md`, failing tests showed the lock erased torn bytes and refused retained torn records. Recovery now only appends a separating newline in `resume`; `exclusive` only locks. Shared series readers ignore unparseable lines, retaining their bytes; a started campaign without a parsed result remains a counted crash. SIGKILL regressions retain partial JSON and UTF-8, pass the mirror's own copy and verification checks, and resume idempotently. Targeted checks: 29 passed. Full suite: 396 passed, 2 failed (the expected clean-tree kernel witness and Lean run differential, missing policy and funding), 2 skipped, 4 xfailed. The human authorizes commits with precisely those missing-data failures; no data, tokens or deployment accessed. Reverse by reverting the code, never truncating the log.

## 2026-11-02 08:27 UTC (03:27 EST): ops-fixes — mirror prefix snapshots (builder, advisor ruling 2)

Initial-copy and incremental-copy races failed before the fix: a body and row published after enumeration made a healthy mirror refuse the run. Each volume now captures day-file sizes before enumerating other files, including raw bodies, and copies only those prefixes. Newly created day files wait until the next run. The datalayer-history parser/refusal is deleted; malformed JSON and UTF-8 no longer wedge later volumes. Targeted checks: 18 passed; full suite: 398 passed, only the same 2 authorized missing-data failures, 2 skipped, 4 xfailed. No recorder or frozen input changed. Reverse by reverting the code; retained recordings stay untouched.

## 2026-11-02 08:30 UTC (03:30 EST): ops-fixes — bounded HL verification (builder, advisor ruling 3)

Failing tests reproduced backlog draining in one step and a permanently failing head. Each step now runs pending first polls before at most one verification. A verification is retried on later steps, but its third failed attempt writes a dropped/error poll naming kind, coin, boundary and attempts before removing it; empty data and found=false preserve the poll schema without inventing a value. Tests cover transient failures at the beginning, middle and end, persistent failures draining, first-poll priority and one four-hour batch. Full suite: 400 passed, only the same 2 authorized missing-data failures, 2 skipped, 4 xfailed. The previously recorded boundary weight deficit remains unchanged; no budget or deployment changes. Reverse by reverting the code.

## 2026-11-02 08:32 UTC (03:32 EST): ops-fixes — per-file Oracle publication (builder, advisor ruling 4)

Failing tests reproduced checksum transfers, rereading unchanged hard links and one divergence blocking healthy files. `--checksum` is removed; same-inode files need no comparison. Under the existing destination lock, each staged file is published if it extends its destination; divergent files alone are refused, all named loudly, while healthy/new files still publish. The last-good marker stays unchanged on any refusal. Equal-size divergence tests force different mtimes: equal-size/equal-mtime changes are deliberately outside rsync's quick-check guarantee. Local fixture tests, including overlapping pulls and SIGKILL before replacement: 14 passed. Full suite: 406 passed, only the same 2 authorized missing-data failures, 2 skipped, 4 xfailed. No SSH, real host configuration or deployment accessed; PROGRESS.md itself is untouched. Reverse by reverting the scripts.

## 2026-11-02 08:34 UTC (03:34 EST): ops-fixes — C4.3 per-agent budget evidence (builder, advisor ruling 5)

Four failing synthetic mutations showed an agent at 101 evaluations, an absent agent's budget, an absent campaign's budgets and null budgets all passed the evidence check. The existing stage 4 check now requires four named per-agent counts for each campaign, each at most 100; exactly 100 passes. This enforces C4.3 as written, changing neither thresholds nor promotion counting. Full suite: 410 passed, only the same 2 authorized missing-data failures, 2 skipped, 4 xfailed. No live evidence inspected. Reverse by reverting the test guard.

## 2026-11-02 08:35 UTC (03:35 EST): ops-fixes — correction and mirror documentation (builder, advisor ruling 6)

The advisor committed bb8f502 on the clean-tree test result: 395 passed, 2 failed, 2 skipped, 4 xfailed. This corrects the earlier entries' claims that no commit was made and that PROGRESS.md recorded the blocker; PROGRESS.md was unchanged on this branch. The two failures were the absent `data/store/policy.json` in `kernel/tests/cli/test_differential.py::test_kernel_matches_witness` and absent funding revisions in `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit`, not code regressions. These fixes follow `audit/reviews/2026-11-02-claude-ops-fixes.md` and the advisor's six rulings supplied by the human. Tests first failed on the missing correction and stale documentation; CLUSTER.md §5 now states the prefix snapshot rule and verification's missing-manifest refusal. Earlier audit entries remain byte-for-byte intact. The data-backed full suite remains due in the main tree at merge; this work does not access it or deploy. Reverse the documentation by reverting its diff; corrections remain append-only.

2026-11-02 08:37 UTC (03:37 EST): Final `nix develop -c pytest -q -n 8`: **412 passed, 2 failed, 2 skipped, 4 xfailed**; the only failures are the two missing-data tests named above. No exclusions, new xfails or worker crashes. Fresh runner/report import enumeration and a diff check confirm no thesis-manifest input, agent harness input, thesis source, kernel source or PROGRESS.md changed. Branch remains `ops-fixes`; no deployment, real token, cluster or recording access. The data-backed merge suite and any independent post-fix review remain for the advisor; no such result is claimed here.

## 2026-11-02: ops-fixes — dropped verification purpose (review B1)

The recorder's dropped-verification assertion and a two-host `availability.merge` regression failed first: local's dropped poll displaced the other host's real reference. Drops now use purpose `dropped`, leaving the existing completeness and reference readers unchanged. Both regressions and the recorder, availability and execution suites pass (19 tests); the merged reference is the other host's actual value. No recording, frozen identity or deployment changes; reverse by reverting the code.

Full suite before the B1 commit: **413 passed, 2 failed, 2 skipped, 4 xfailed**; only the human-authorized clean-tree kernel witness and Lean differential missing-data failures. No exclusions or new xfails.

## 2026-11-02: ops-fixes — single-line Oracle pull blockers (review B2)

Four regressions failed first: multi-file divergences, a newline in a divergent filename and a synthetic SSH timeout left stale blocker continuations after a good pull; the publisher also emitted separate divergence lines. Publication errors now join with `; `, rsync retains only its last output line under `pipefail`, and pull errors flatten newlines before reporting or updating status. All 17 local Oracle tests pass, including byte-for-byte status recovery with unrelated sections preserved and the synthetic SSH address absent from the report. Only temporary fixture status/configuration files were used; real PROGRESS.md, host configuration, tokens, data and SSH were untouched. Reverse by reverting the scripts.

Full suite before the B2 commit: **416 passed, 2 failed, 2 skipped, 4 xfailed**; only the same two authorized missing-data failures. Shell syntax and diff whitespace checks pass.

## 2026-11-02: ops-fixes — remove the one-off commit pin

A temporary Git shim refusing only `git show bb8f502:...` reproduced the obsolete correction test's failure (one failed, two passed), without changing repository history. Deleted that entire test, retaining the general timestamp checks; the same unreachable-commit simulation now passes both remaining tests. The audit correction itself remains unchanged. Reverse by restoring the deleted test if that historical dependency is deliberately wanted.

Final full suite before the deletion commit: **415 passed, 2 failed, 2 skipped, 4 xfailed**, with 10 existing multiprocessing deprecation warnings and no worker crashes. Only `kernel/tests/cli/test_differential.py::test_kernel_matches_witness` (missing policy) and `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit` (missing funding revisions) fail, as authorized for this clean tree. No exclusions or new xfails. Branch/worktree and protected-file checks pass: PROGRESS.md unchanged, audit append-only, no frozen source changes, no data/token/cluster access or deployment.

## 2026-11-02 08:52 UTC (2026-11-02 03:52 EST): the ops fixes merge to main (advisor)

- Built by GPT, reviewed twice by a fresh Opus (`audit/reviews/2026-11-02-claude-ops-fixes{,-2}.md`), whose findings were fixed and rechecked; `pull.sh`'s pipeline was confirmed under `pipefail`. The Oracle pull goes live with this merge; the recorder and mirror changes wait for an image. `hl` and the mirror CronJobs roll with the next image; `sources` not before 2026-11-03 00:18 UTC (2026-11-02 19:18 EST). Reverse: revert the merge.

## 2026-11-02 09:16 UTC (04:16 EST): the thesis bundle awaits review (builder, on `thesis-fixes`)

All ten findings reproduced and are fixed, and the differential against GPT's positions agrees on 9 classes. It found three further bugs, fixed, and one design choice for the review, when a core open is known (`audit/reviews/2026-11-02-thesis-bundle.md`). Nothing is frozen. **Reverse:** drop the branch.
## 2026-11-02 09:41 UTC (2026-11-02 04:41 EST): the thesis bundle isn't refrozen; GPT's review ruled on (advisor)

- **Said:** `audit/reviews/2026-11-02-gpt-thesis-fixes.md`: blocked, F1 to F9, each with a counterexample; the fixes for the original findings hold up. A fresh Opus review was started and hit Cornell's limit, so it reviews the next round. Confirmed by the advisor: the rounding fix widens a frozen threshold (`thesis/positions.py`).
- **Rulings:** every finding is fixed, with no waivers. Discrete decisions (the cost-cell boundary, invalidation, the sign of a return, admission) use exact arithmetic rather than a tolerance. Sizing waits for reconciliation; a warm cache gives what a cold one does; resolution separates each thesis from unrelated markets, publishes status apart from slow work, and stamps real times; a benchmark's size, base rate and p come from one set of inputs; a required gap is retried until filled, with no age limit; a legacy body is validated before reuse, its damaged bytes kept and the repair recorded; eligibility is checked at the commit boundary. The differential gains the omitted boundaries, absolute money comparisons, intermediate state, and the production adapter, and it reports raw disagreement apart from approved-spec agreement.
- **Spec:** GPT's four dated readings (P_e as the reference open; funding after a missing bar; a reservation's release; a core open's availability) are drafted under `audit/stage10/`, reviewed with the round, and committed alone as `criteria: stage 10` before the refreeze. None loosens a threshold, and each is stated as a revision, never an edit.
- **Next:** a builder after campaigns 9 and 10, then GPT and a fresh Opus on that round, then the refreeze. Tonight's sessions, if they run first, run on the current version and don't count. **Reverse:** nothing is frozen.

## 2026-11-02 12:53 UTC (2026-11-02 07:53 EST): C4.5 v2 failed as written, 2 of 10 counted; v3 starts (advisor, on the human's standing go)

- **What:** v2's log (`audit/stage4/null-v2.jsonl`, sha256 `4b321d6e…`, matching the mirror's manifest) has ten campaigns; `swarm-null-2-N2-5` and `-9` count. In each an agent ran `/work/mm-agent` instead of `./mm-agent`, was refused by the frozen permission, stopped asking for input, and made no evaluation: 2 of 40 agents. `N2-9` is recorded as a crash because that dead agent also tripped `cross_agent_history`'s missing log, the bug fixed in `b92521e` and held back from v2's image; its ledger shows no holdout disclosure and no evaluation by that agent. Nine campaigns recorded their gate outcome: no promotion, finalist or screened candidate. Not a pass, and no false discovery was observed. Its test is a strict xfail.
- **v3:** the human, 2026-11-02 05:47 UTC (00:47 EST): "if v2 fails go with v3 autonomously without my permission". The contingency's text goes in alone as `criteria: stage 4`; its counting code gets an independent review; it runs on `swarm-null-3-N2-0` to `-9`.
- **Reverse:** none for v2's failure.

## 2026-11-02 22:37 UTC (17:37 EST): round 3's market cache: only a shown row is held in memory (builder)

- GPT's daily regression had an hourly twin it did not report: a read at 00:00:00.001 fetched the 00:00 candle before it showed, and at 00:02 that held row answered "newest row held" while the 23:00 bar, just final, was dropped. Holding only rows already shown removes both; no daily row is ever held, since a daily row shows when it is final. A randomized warm-against-cold test covers both.
- The suite's hang near 98% (entry of 2026-11-02 17:35 UTC (12:35 EST)), caught live: an xdist worker died during `gate/tests/test_sweep.py::test_sweeps_refuse_an_unfrozen_or_changed_searcher`, and the fork `run_all`'s `Pool` had made of it outlived it, holding the worker's pipes to the controller, so the controller never saw it go. Killing that one orphan by PID ended the run, with the crash reported; the test passes alone. Why the worker died is not established: no kernel or coredump record.
## 2026-11-02 13:08 UTC (08:08 EST): B2's freeze reviewed (human)

- The human, on B2's freeze (2026-11-02 00:57 UTC (2026-11-01 19:57 EST)): "its probably fine". It stands.

## 2026-11-02 17:35 UTC (12:35 EST): C4.5 v3's counting code clears review (advisor)

- GPT reviewed it four times (`audit/reviews/2026-11-02-gpt-c45-v3-code-{1..4}.md`); the last says RUN. A class is recomputed from a campaign's directory, never read from its log row; missing or unreadable evidence is unresolved; every declared campaign with a directory counts. A dry run on v2's ten real campaigns, not judged, shows every agent's records reconciling, which also caught a false refusal before commit. The series starts once the thesis work is off Cornell. C4.5 v3's text cites this contingency as 03:43 UTC (2026-11-01 22:43 EST); its heading reads 03:44 UTC (2026-11-01 22:44 EST), the same entry. The suite has hung three times near 98% under parallel workers, cause unknown, passing on rerun.

## 2026-11-02 18:23 UTC (13:23 EST): thesis round 2 not refrozen; third round ruled on (advisor)

- **Said:** `audit/reviews/2026-11-02-{claude,gpt}-thesis-round2.md`: F1 to F4 and most of the rest hold, and neither would refreeze yet; GPT lists B1 to B5, Opus R1 and R2 first. Only reachable triggers were asked for.
- **Fix, each from a failing test:** a required daily prefix is repaired, not exempted (B1); one failing market in a pass no longer delays unrelated theses' scores, with a test of elapsed time (B2); exact money survives the ledger round trip at any length, tested over a long track (B3); a committed registration's retry returns it, without new admission or market reads (B4); a body's repair record survives a kill, written before the rename, and the Oracle's refusal of a repaired body is documented (B5); each thesis records its cutoff, E_r, reconciled hour and reservations (R1); legs are shape-checked before the listing read (R6); SCORING.md gets its exactness line. `*.tmp` is excluded in the mirror and pull, outside the manifest (R7). R2's stall is real but small by metadata: the running version's two main sessions show two tool timeouts in one, none in the other; so a call reuses market tails it already fetched.
- **Readings:** the draft becomes rules, with the reconciliation consequence and reading 4's receipt qualified, committed alone as `criteria: stage 10` before the freeze; GPT then updates its scorer and positions from the committed text, C10.4 reruns.
- **Next:** a narrow check of this round's diff for reachable defects only, then the refreeze, between 00:00 and 00:10 UTC (19:00 and 19:10 EST) if it can be, so the first day is clean. **Reverse:** nothing is frozen.

## 2026-11-02 19:01 UTC (14:01 EST): thesis round 3's check: one regression, fixed before the freeze (advisor)

- GPT (`audit/reviews/2026-11-02-gpt-thesis-round3.md`) confirms B1 to B5, R1, R6 and R7 fixed, and reproduced a regression in R2's cache shortcut: after a midnight read, the 00:10 read drops the daily candle that just became final, so a market with its 90th day is wrongly excluded. A warm cache must give what a cold one does across that transition, as a failing test first. The check ran with shell access because that review tree's config denied only four tools, leaving `execute` open; it ran only `git show` and synthetic tests, read no data, and CLAUDE.md's seven-tool recipe does deny the shell, tested. GPT's positions module made no tool calls, so its independence stands.

## 2026-11-03 00:02 UTC (19:02 EST): stage 10 refreezes as `thesis-310449610583` (advisor)

- **What:** frozen 2026-11-03 00:02 UTC (2026-11-02 19:02 EST). C10.5's window restarts there; `thesis-a476a910d501` keeps its rules and its evidence is neither pooled nor carried over. It bundles the bug hunt's fixes in three reviewed rounds, each finding from a failing test; exact money, so no threshold widens; the readings committed alone (`1c59924`).
- **Why:** the old code read invalidation at the wrong price, picked the wrong cost cell at the default $1000, could score an exactly zero return as a win, and could lose sessions on a crash. Two days of a 28-day window were lost by refreezing now; waiting only raises that.
- **Said:** GPT (`audit/reviews/2026-11-02-gpt-thesis-fixes.md`, `-round2`, `-round3`, each blocking, each ruled on) and a fresh Opus (`-claude-thesis-round2`). GPT's narrow check of the last commits found one more cache edge, fixed from a failing test by the advisor (`fc3f9a4`) and not re-reviewed, since the change is small and only adds a read. C10.4 reran on GPT's scorer, updated from the readings alone: agrees on its 1,000 sets. GPT's positions module keeps its reviewed source patches rather than an update, those patches being the readings. 665 tests pass in the tree with data.
- **Reverse:** a later version can follow; this one's window is what it costs.

## 2026-11-03 00:25 UTC (19:25 EST): C5.3's segment reported; `sources` rolls

- `audit/stage5/availability-{discourse,snapshot}-20261103.json`, reported, not judged: 126.3 hours, `clock_bound_ms` max 350.346 over 1,081 samples, valid; polls without overlap 0; claimed-rule failures 0; one failed discourse poll. `sources` rolls to `sha256:8ad0b655…`, the segment having ended 2026-11-03 00:18 UTC (2026-11-02 19:18 EST).

## 2026-11-03 02:56 UTC (21:56 EST): the thesis track comes first on Cornell; C4.5 v3 waits for the resets (advisor)

- **Why:** the thesis's first day (`thesis-310449610583`, 2026-11-03) took about 0.10 of Cornell's week, its only account, and Cornell's week (0.63 now) resets 2026-11-08 05:00 UTC (00:00 EST); TAMU's (0.96) resets 2026-11-07 04:00 UTC (2026-11-06 23:00 EST). Four more days need about 0.40 of the 0.37 left. A missed thesis day can't be made up in its window; a v3 campaign can wait.
- **So:** `agent-series` stays as deployed. Its pacing assumes 0.5 of a week for a cohort with no measured campaign, which keeps v3 off both accounts until TAMU's reset, where its first campaign runs; that bug is left in place this week on purpose and fixed after (read measured need across a series' earlier logs). Claude work on Cornell is kept to the minimum, and heavy work goes to GPT. A personal-account token for the thesis pod (`claude setup-token`, the human's) would remove the risk to 2026-11-07's session.

## 2026-11-03 03:02 UTC (22:02 EST): GPT's budget is nearly gone; it is kept for independent checks (advisor)

- GPT has about 3% of its week left, resetting about 2026-11-04 12:00 UTC (07:00 EST); the advisor had read the human's "4%" as used. The crash-test builder was stopped after 4 minutes, with nothing committed and its branch deleted; the N1 diagnosis had finished. Until GPT resets, it runs only reviews a decision needs. The personal account is at 98% of its week and resets 2026-11-04, after which its token can carry the thesis pod.
- 2026-11-03 03:25 UTC (2026-11-02 22:25 EST): `gate/agent/campaigns.py::need` now measures each window's maximum campaign use across sibling `swarm-null*.jsonl` or `agent-null*.jsonl` logs of the same family, so a new cohort inherits earlier measurements; the 0.8 ceiling, unmeasured-window fallback and other pacing rules are unchanged. Reverse: revert this pacing-fix commit; no deployment.
- 2026-11-03 03:43:04 UTC (2026-11-02 22:43:04 EST): ops hunt F1 reproduced: validate the entire seed destination plan before staging, refusing escapes, symlinks, duplicates and file/parent collisions; staging is invocation-owned, never cleared beneath another helper. Reverse: revert the ops-fix commit; no cluster action or frozen identity change.
- 2026-11-03 03:43:04 UTC (2026-11-02 22:43:04 EST): ops hunt F2 reproduced: preflight all live destinations, skip identical existing files and publish verified temporary bytes with a no-clobber hard link, preserving concurrent appends and surviving a killed copy. Reverse: revert the ops-fix commit; existing recordings are untouched.
- 2026-11-03 03:43:04 UTC (2026-11-02 22:43:04 EST): ops hunt F3 reproduced: retries launch from the original record's checked content-addressed inputs and commit/image, never current local files; collection also requires equal calibration and image identities. Reverse: revert the ops-fix commit; no existing sweep is rejudged.
- 2026-11-03 03:43:04 UTC (2026-11-02 22:43:04 EST): ops hunt F4 reproduced: exclusive result-directory creation consumes a run name even if submission fails or is killed, and Kubernetes creation cannot silently adopt an old Job. Reverse: revert the ops-fix commit; no Job is submitted here.
- 2026-11-03 03:43:04 UTC (2026-11-02 22:43:04 EST): ops hunt F5 reproduced: take the image digest from skopeo copy's invocation-local digest file rather than inspecting the mutable destination tag. Reverse: revert the ops-fix commit; no image is built or pushed here.
- 2026-11-03 03:43:04 UTC (2026-11-02 22:43:04 EST): ops hunt F6 reproduced with a killed client: create server-named helper pods and read/delete only the returned name, so a leftover terminal pod cannot supply another invocation's result. Reverse: revert the ops-fix commit; tests use fake pods only.
- 2026-11-03 03:43:04 UTC (2026-11-02 22:43:04 EST): ops hunt F7 reproduced: pair each gate diagnostic with its acceptance predicate, retain all diagnostics, name failed checks and exit nonzero through both pod and caller. Reverse: revert the ops-fix commit; frozen checks themselves are unchanged.
- 2026-11-03 03:43:04 UTC (2026-11-02 22:43:04 EST): ops hunt F8 reproduced during overlap and after SIGKILL: publish generation-addressed snapshots atomically in the manifest, verify only that generation under a shared lock, retain old generations, and share only append-only log prefixes/unchanged bytes; flat paths remain aliases, never verification authority, and every recording refusal remains. Reverse: revert the ops-fix commit before deployment; no mirror or recording is accessed here.
- 2026-11-03 03:49 UTC (2026-11-02 22:49 EST): GPT's independent positions module was updated from the criteria's readings of 2026-11-02 and SCORING.md alone, and installed as `thesis/tests/gpt_positions.py`; the differential drops four of its five source patches and passes in full (67 passed, 1 strict xfail), so those readings are now independently implemented, not patched in. It agrees on every fill, reservation and hourly equity. Two differences remain. A position no leg of which entered has no managed return here and 0 in GPT's file, which its docstring lists as open: kept as the one reading. A spread with one leg entered gets no managed return from `thesis/positions.py` though the equity carries its P&L: a defect, strict xfail, in `as_managed_mean` only, which has no threshold and no interval (criteria, "Portfolio returns"). `thesis/positions.py` is in the manifest and a refreeze restarts the forward window, so it is fixed at the next refreeze, not for this. Reverse: revert this commit.

## 2026-11-03 04:20 UTC (2026-11-02 23:20 EST): the mechanism check's two defects are qualified, not forked (advisor)

- **What.** GPT's hunt found that the frozen kernel's mechanism check omits a closing fill's costs from both branches and drops undefined conditions from its coverage denominator (`audit/reviews/2026-11-03-gpt-hunt-gate.md`, findings 1 and 2). The advisor read the code and agrees; neither is yet reproduced by a run. The kernel stays frozen through C4.5 v3, with the qualification now under the criterion, and the new engine's criteria must fix both, with the reconciliation and adversarial cases the consultation lists. Finding 4, `INSERT OR REPLACE` past the append-only triggers: the guarantee is narrowed to the kernel's conforming writers, and it is fixed once, in the new engine's ledger.
- **Why.** No judged result had a candidate reach the check (stage 3's real run, C3.2 v1 to v3, C4.5 v1 and v2). v3 is a null smoke test on one frozen kernel shortly before a planned replacement, and a fork would need fresh identities and a later holdout for any real arm. The advisor's first reading, that a pre-holdout filter cannot raise false discoveries, was wrong: through Holm, removing a finalist can enable another's promotion, and the consultation corrected it.
- **Reviewers.** GPT, consulted fresh without this conclusion, tried to refute the findings, confirmed them with narrowings, and recommended this (`audit/reviews/2026-11-03-gpt-mechanism-consult.md`). A fresh Claude review is queued for 2026-11-04 and must land before v3 starts at 2026-11-07 04:00 UTC (2026-11-06 23:00 EST).
- **Would change it.** Another real campaign before the new engine, the engine substantially delayed, evidence the defects decide active finalists, or a defect reaching portfolio returns, the loss bound or holdout isolation.
- **Reverse.** Before v3 starts, fork the kernel under fresh campaign ids. After, a fork never reruns what it judged.

## 2026-11-03 04:22 UTC (2026-11-02 23:22 EST): the ops hunt's eight findings are fixed (GPT, reviewed by the advisor)

- 2026-11-03 04:06:33 UTC (2026-11-02 23:06:33 EST): replaces the generation design of 623fe5d's F8 line: retain flat files and MANIFEST.json, atomically replace whole-file copies, and confirm mirror mismatches against a later manifest within twenty minutes (next ten-minute run plus copying allowance), while source-prefix mismatches fail immediately; unpruned generations exhaust storage/link counts, aliases require a needless live-layout migration, and NFS/read-only flock is untested. Successful seed stages are removed; failed stages remain diagnostic evidence. Reverse: revert this replacement before deployment; no cluster or recording accessed.
- 2026-11-03 05:10:34 UTC (2026-11-03 00:10:34 EST): GPT centralizes all six production process pools on gate.compute.Pool's forkserver context, passes calibration parallelism explicitly and transfers campaign locks to fresh workers; assumes frozen identities and judged inputs remain unchanged. Original sweep hang not reproduced (0/384 before, 0/384 after); controlled inherited-thread-lock deadlock 3/3 with fork versus 0/3 with forkserver. N1/N2/N3 synthetic campaigns agree across methods in results and ledger rows except wall-clock fields; no child-monkeypatch tests needed rewriting. Requested foreground suite: 754 passed, only the two allowed missing-data failures, 2 skipped, 6 xfailed; frozen files, kernel, cluster and PROGRESS.md untouched. Reverse: revert this migration; original hang's attribution remains unconfirmed.
- 2026-11-03 04:37 UTC (2026-11-02 23:37 EST): findings 1, 2 and 4 of the gate hunt now reproduce on the built kernel, each failing at its own assertion (`gate/tests/test_mechanism_defects.py`, strict xfails): both mechanism branches report -2.001 bps against a hand-computed -4, omitting 1.999 of closing costs; a prediction undefined on 200 of 202 held exposures passes at a reported 50% against an actual 0.495%; a separate connection's `INSERT OR REPLACE` rewrites a results row. The qualification of 2026-11-03 04:20 UTC (2026-11-02 23:20 EST) stands, and these replace its "neither is yet reproduced".
- 2026-11-03 04:36:44 UTC (2026-11-02 23:36:44 EST): Confirmed gate hunt finding 3 with failing C4.5 v3 regressions: `swarm_evidence` now checks every campaign experiment's kernel against the series-recorded hash, classing a mismatch (or missing expected identity) unresolved with its reason, while promotions still take precedence; live and summary classification share that path. `check_frozen` rechecks the series kernel after pacing and before a campaign starts. Fresh GPT review found no blocking issue; 109 targeted tests passed; full non-slow suite: 706 passed, 2 skipped, 6 xfailed, only the two known missing-data failures (`test_kernel_matches_witness`, `test_runs_agree_bit_for_bit`), using a shorter CLI `--basetemp` after the prescribed command hit Unix-socket path limits and timed out. Frozen harness and kernel identities unchanged; no deployment. Reverse: revert this commit.
- 2026-11-03 15:20 UTC (2026-11-03 10:20 EST): all six findings of the kernel hunt (`audit/reviews/2026-11-03-gpt-hunt-kernel.md`) reproduce on the built kernel as strict xfails (`gate/tests/test_kernel_defects.py`). Finding 1, a delisting lookahead, meets the stated reversal condition of the mechanism decision of 2026-11-03 04:20 UTC (2026-11-02 23:20 EST) but cannot occur in N1 to N3, which never delist; findings 2 to 5 reach returns or reported equity and can occur there. The human said at 15:12 UTC (10:12 EST) that delaying C4.5 v3 is fine. Whether to fork the kernel before v3 goes to review.
- 2026-11-03 23:58 UTC (2026-11-03 18:58 EST): the thesis moves to the personal account's token, a new `claude-token` key `PERSONAL` that the human added, because Cornell's week could not carry four more thesis days. Each runner now names the key it reads; the series' pool is unchanged, so v3 cannot start on the fresh account. Same image; the pod rolled while idle, before the 2026-11-04 00:10 UTC (2026-11-03 19:10 EST) session. Reverse: set the thesis's key back to `CLAUDE_CODE_OAUTH_TOKEN` in `ops/live.py`, apply, and delete the pod between sessions.
- 2026-11-03 23:49:22 UTC (2026-11-03 18:49:22 EST): C4.5 v3's `swarm_class` now requires exactly `SWARM_AGENTS` evidence records before a non-promoted campaign can be established; the unchanged missing-agent assertion reproduced the defect and loses its strict xfail. Changed files are outside both frozen identities; the UTF-8 recorder defect stays unfixed because `ingest/live.py` is stage-10-manifest hashed. No data, cluster, kernel or PROGRESS.md changes. Reverse: revert this fix commit.

## 2026-11-04 00:03 UTC (2026-11-03 19:03 EST): C4.5 v3 runs on the frozen kernel under an exact qualification; the nine defects are fixed in the spec (advisor, the human approving)

- **What.** v3 runs the frozen kernel. Its qualification, reviewed by GPT before commit, now sits beneath C4.5 in `audit/criteria.md`: a finalist's raw holdout p-value is valid, bankrupt paths included, if its pre-absorption step returns have nonpositive conditional means and are almost surely at least −2, which this kernel does not establish. v3 reports each finalist's turnover and lowest committed step return, and flags any promotion that masks a campaign not established. `gate/NULLS.md`'s bankruptcy paragraph is corrected. All nine reproduced defects are fixed once, in `reference/SEMANTICS.md`, Lean's L1 (to include listing intervals) and the stage 7 port, before any real campaign; kernel findings 1, 3 and 2 first. Before v3 starts, the series rolls to an image with `956066c`. The recorder's torn-UTF-8 defect waits for the next refreeze, `ingest/live.py` being in the thesis manifest.
- **Why.** v3's verdict counts promoted and unresolved campaigns as failures, so a spurious promotion pushes it toward failure, except a promotion that masks a not-established campaign, which is flagged. v3 is a smoke test of the swarm's code paths, and a Rust fork would fix the same defects a third time, before the stage 7 port and the Lean engine that must fix them anyway.
- **Reviewers.** GPT, consulted fresh, recommended a corrective fork and a fresh cohort (`audit/reviews/2026-11-03-gpt-fork-consult.md`). Claude, fresh, recommended this, deriving the bound (`2026-11-03-claude-fork-review.md`). GPT checked the derivation: sound, and stronger than stated, but conditional on the −2 bound, which the kernel's unbounded held exposure and N2's unbounded wicks leave unestablished (`2026-11-04-gpt-bound-check.md`). The human approved at 2026-11-04 00:03 UTC (2026-11-03 19:03 EST).
- **Reverse.** Before any v3 campaign starts: stop the series, fork the kernel, and run fresh campaign ids. After, a fork never reruns what v3 judged.
- 2026-11-04 00:26:00 UTC (2026-11-03 19:26:00 EST): GPT implements C4.5's 2026-11-04 qualification as reporting only: each finalist's kernel turnover and minimum absorbed net step return, separately for the gate's first filled search evaluation and committed holdout result; named unavailable evidence; and each promoted campaign's establishment absent promotion, audit completeness, distinct filled trials, evaluating agents, history receipts and masking flag. Assumes the gate's committed selections identify frozen finalists when the series log is incomplete; missing search-finalist lists remain named, not reconstructed. Tests written first; requested foreground suite: 981 passed, 2 skipped, 21 xfailed, only the two permitted missing-data failures (test_kernel_matches_witness, test_runs_agree_bit_for_bit). No class, verdict, threshold, frozen file, market-data access, campaign evaluation, PROGRESS.md or cluster change. Reverse: revert this reporting commit; no deployment.
- 2026-11-04 00:41 UTC (2026-11-03 19:41 EST): image `sha256:5d59960e71ffdbe51a9ddbddc78c3d2f07864d7c177b271011bddca8dfc1ba28` (`fb220cc`) passed the pod gate and now runs `agent-series`, `mirror` and `mirror-verify`, carrying the swarm identity check, v3's report and the pacing fix; `agent-series` was recreated before any v3 campaign started (an empty log, no campaign directory). The new gate first failed its own session check, which wanted an empty stop reason where a finished session records `finished`; fixed in `fb220cc`. The thesis and recorders keep `sha256:8ad0b655…`.

## 2026-11-04 05:05 UTC (00:05 EST): stage 7 ports the frozen kernel first, then fixes the nine defects (the human)

- **What.** C7.4 and C8 stay as written. The port reproduces the frozen kernel byte for byte at a tagged commit, where C7.4 and C8's reproduction clause are judged (dated revision under C8). The nine defects are then fixed in that one implementation, each with its test, never behind a switch. This orders the stage 7 part of the decision of 2026-11-04 00:03 UTC (2026-11-03 19:03 EST).
- **Why.** Both reviews of the spec revision found that fixing the defects in the port contradicts C7.4's byte identity and C8's reproduction (`audit/reviews/2026-11-04-claude-nine-defects-review.md` finding 2). Byte identity before the fixes is the strongest check that the port is faithful; revising it to explained differences would loosen a frozen requirement.
- **Reverse.** Before the tagged commit: a dated revision of C7.4 and C8, the human's.

## 2026-11-04 05:05 UTC (00:05 EST): the corrected engine bounds exposure by the account's own stop-out at 4 times equity (advisor)

- **What.** The spec revision of branch `claude/nine-defects-spec-qhpaks` adds behaviour no defect required: the book is stopped out when its gross exceeds Λ = 4 times equity, a fill is refused if it leaves gross above that, and the synthetic nulls clip ε at 0.3 and wicks at 0.1. Adopted as policy for the corrected engine. It is the account's own stop-out, never presented as the venue's liquidation; the bound holds by construction only on gapless synthetic nulls, and on real markets is a stated assumption.
- **Why.** The holdout theorem needs pre-absorption returns of at least −2, and with held exposure unbounded nothing gives that. Reusing step 3's liquidation and the venue's order-time margin check adds no mechanism.
- **Reviewers.** GPT: a policy choice, not a theorem, reasonable for a bounded null design; the fill exception as written breaks the leverage invariant and the real-market extension is false (`2026-11-04-gpt-nine-defects-review.md` findings 1, 4). Claude: the simplest shape it can derive, with a 2× book now stopped at an adverse move of 1/3 (`2026-11-04-claude-nine-defects-review.md` finding 6). Both findings go to the revision.
- **Reverse.** Before the stage 7 port implements it: revise the spec. It judges nothing until then.

## 2026-11-04 07:12 UTC (02:12 EST): B3 round 3, the second round's rulings applied to the draft (builder)

- Applied under `audit/stage7/b3-draft/`; nothing frozen; it goes to review. Choices the rulings left open: `refmm resolve` (`reference/lean/Main.lean`) reads each case text by RULES.md §1 with its own reader, reusing `Ref/Json.lean`'s string reader and binary64 rounding, so a large integer stays an integer and an overflowing non-integer in an undeclared member is ignored; the observation format has its one home in §7; a case's Parquet image is one file per row holding its metadata and declared members; the generator gains a reportedTime correction raised to what it replaces and a tombstone holding another slot, since the corrected tags showed 0 and 8 stores. Run here: all 134 hand cases equal Lean's results, every REACHED tag on at least 10 stores, and `resolveAll`'s observations equal its timelines' delivery (`lean_check.py`). The escape lost from the example was lost again by this session's file tool, which decodes `\u` escapes; written back as bytes, so reviewers check the bytes. Reverse: revert this commit.

## 2026-11-04 10:20 UTC (05:20 EST): B3 round 4, the third round's findings answered under the advisor's rulings (builder)

- Every finding of `audit/stage7/b3-round3-review-{claude,gpt}.md` answered in `audit/stage7/b3-draft/` and `refmm resolve`; nothing frozen. C7.6's size now counts delivered pairs only (a key in U, a query at or after one of its entries' fetchedAt), each loader emits §7's whole result from its production resolver, and `generate(resolve)` is the shortest prefix of the seeded stream reaching 1,000 and 200 (1,002 and 787 over Lean, 304 stores): it loosens nothing, as counted. A tombstone's lineage is never read; a null or absent lineage elsewhere and an integer outside int64 do not decode, in JSON as in Parquet; one string mapping (Utf8 or LargeUtf8); holdout staging names `test_holdout_check_reads_event_times_alone`; the two-run carve-out moves onto the store pairs; Lean keys a signed-zero entity once; `lean_check.py` checks cardinality. Choice left open: "200 per required class" read as the one class C7.6 requires, keys of at least two eligible revisions. Run here: 149 of 149 hand cases equal Lean, every REACHED tag on at least 42 stores, observations equal their timelines' delivery. Reverse: revert this commit.
