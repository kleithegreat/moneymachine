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
