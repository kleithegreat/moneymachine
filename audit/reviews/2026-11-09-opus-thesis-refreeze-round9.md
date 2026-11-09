# Review: thesis refreeze, round nine (Opus, fresh session)

- **Reviewer:** Claude Opus 5.5, a fresh session with no part in rounds four to nine or in the hunt they fix.
- **When:** 2026-11-09 06:48 to 07:06 UTC (2026-11-09 01:48 to 02:06 EST).
- **Reviewed:** `thesis-refreeze` at `f4db799` (round nine, `6dc18a3`, built by Sonnet; build record's "Round nine" section in `audit/reviews/2026-11-08-sonnet-refreeze-round7-build.md`), three-dot from `d7448d2`, against `audit/reviews/2026-11-09-opus-hunt-thesis.md` (F1-F4 and its lower notes), stage 10 of `audit/criteria.md` (with the revision of 2026-11-09 02:31 UTC (2026-11-08 21:31 EST)), and the two criteria clauses round nine needs.
- **Method:** a clean worktree with no `data/`; the hunt's reproductions r1-r4 rerun on `d7448d2` (a `git archive`) and on `f4db799`; three new reproductions in `2026-11-09-opus-thesis-refreeze-round9/` (run from the worktree root with `TMPDIR=/tmp nix develop -c python <file>`); the sharded suite. No recording, holdout, cluster or venue endpoint was read.

## Verdict

**Ready after fixes.** F2 and F3 are fixed at their cause, and F1's per-market isolation and the benchmark loop's isolation hold. But F1's fix makes a single transient failure final for the date, which can fail C10.5 on one venue blip (N1). F4's fix misses the unreadable-FILE case in real transcripts (N2). The N1 fix changes F1's design (a retry window and its constant), so by CLAUDE.md a recheck is owed on another model than this one.

## The hunt's reproductions, before and after

| | `d7448d2` | `f4db799` |
|---|---|---|
| r1, response rewritten in place | bytes lost (142,023 to 47,341) | intact, hash unchanged: **fixed** |
| r2, locally refused call | `match: False` | the script's records lack `request` (its own artifact); adapted as `n3_audit_probes` (a): `match: True` for the arity case. The FILE case: N2 |
| r3, one bad listing | 19 of 19 passes raised, 0 attestations, date and batch lost | attested, no miss; benchmark rows then raise `KeyError` from the script's own `costs: {}` stub, not the code: **fixed** |
| r3b, one benchmark market fails | 0 registered, 5 "run missed" | ETH, xyz:XYZ100, xyz:GOLD registered, flx:OIL skipped for its property, BTC "run missed": **fixed** |
| r4, two processes on one cache | 1 raised, 149 of 282 ranges kept | 0 raised, 244 of 244 kept, no unparsable read: **fixed** |

## Findings, ranked

### N1. One transient read failure at the snapshot is now final for the date (medium-high: can fail C10.5)

**Path.** `thesis/runner.py:150-171`: the first exception from a market's daily, hourly or readiness read puts it in `failed`, and `acquire` (`:197-215`) attests at once. Before round nine, any failure raised out of `snapshot` and `forever` repeated the whole acquisition a minute later, so a transient failure healed.

**Failure.** A read raises once Info.post's six attempts are spent (`ingest/hl.py:91-111`): about 31 s of backoff plus up to six 10-s timeouts, so a venue blip of a minute or two. On a Monday, if that blip falls on any of the five benchmark markets' reads, the market is skipped "market read failed at the snapshot", an operational skip. The batch is then not executed, and the revision of 2026-11-09 requires exactly four executed batches: C10.5 fails outright. On other dates, main and no-reading lose the market for the whole date.

**Reproduction.** `n1_transient_blip.py.txt`: BTC's hourly read fails once.
- `d7448d2`: the first pass raises, the next attests with `failed: None`, and BTC, ETH, xyz:GOLD and xyz:XYZ100 are registered.
- `f4db799`: attested with `failed: {'BTC': "HTTPStatusError('502 …, once')"}`, BTC skipped operationally, the batch not executed.

**Fix at the cause.** A failure becomes final only once it has persisted. Retry each failed market, alone, at every acquisition pass, until a fixed give-up before the completion deadline, and attest only when none is failing or that time has passed. Attestation can wait, because no session starts before D + 05:00 UTC (00:00 EST). I propose D + 04:45 UTC (23:45 EST the day before). After that time no retry starts, so at most one retry is in flight (≤ about 91 s); readiness and attestation are local and take seconds. The constant is a choice, stated with its reason in T3. Monday uses the same give-up, because a later attestation would miss main.

### N2. F4's unreadable-FILE case is not fixed for real transcripts (medium: C10.2 false failure)

**Path.** `thesis/harness.py:107` treats a FILE call as refused when the result text starts with `{"ok": false, "error"`. The client exits 1 in that case (`sandbox/client.py:31-33`). Claude Code records a nonzero-exit Bash result as `Exit code 1\n<output>` with `is_error: true`. I observed that format in this CLI's own transcript on 2026-11-09, for a command printing exactly this JSON and exiting 1.

**Failure.** The prefix test never matches a real result. The call counts as sent, has no record, and the session reads `match: False`: the hunt's false failure, unchanged.

**Why the tests miss it.** `test_refreeze_round9.py:171-174` writes the output without the `Exit code` line.

**Reproduction.** `n2_exit_code_prefix.py.txt`: `refused_locally: 1` (the usage case, decided by arity), `unmatched_client_calls: 1`, `match: False`.

**Fix.** The classification in the wording below, with a test built from a recorded CLI result.

### N3. A call that reached the daemon can be classified `refused_locally` (low: passes falsely only with a recording defect)

**Path.** `thesis/harness.py:66-82,101-107`.
- The FILE test reads the output of the whole Bash command, so every FILE call in a command whose output begins with a local refusal is classified refused.
- Arity is taken from shlex tokens, not from the shell's argv. For example, `exit $(cat args)` tokenizes as one argument but the shell passes two.

**Construction.** `n3_audit_probes.py.txt`:
- (b) `./thesis-agent register missing.json; ./thesis-agent register a.json`: both are classified refused, and a.json's record is left unmatched. The check fails closed.
- (c) The same command plus a later `./thesis-agent register b.json` that reached the daemon with no record. a.json's record absorbs it (FILE arguments match by count), and the result is `match: True`. C10.2's claim is false here, and the check passes.
- (d) `exit $(cat args.txt)` is classified refused although it reached the daemon. The check fails closed.

**Fix.** The fix for N2 closes this too. Classify a call as refused only when it is the sole client call in its command and the result is exactly the client's refusal: nonzero exit, and the whole output is the usage line or one `{"ok": false, "error": …}` object. Decide this from the result, not from shlex arity. Under `Bash(./thesis-agent:*)` (`sandbox/session.py:40`), a call that reached the daemon prints the daemon's canonical reply (`registry.canonical`: no spaces, no `error` key) and exits 0. So no reached call can be classified refused.

### N4. Failed markets are not in the attestation record or the report (low-medium: C10.6)

**Path.**
- `failed` is in the attested snapshot's bytes, but not in the `snapshot_ready` record (`thesis/runner.py:213-215`).
- `thesis/report.py:83` lists only those records.

**Outcome changed.** C10.6 ("skips and fallbacks") does not enumerate which markets each date lost. Item 2 of the revision lists each date's attestation fields in the report, and the proposed wording says "recorded in the attestation".

**Fix.** Add `failed` to the record.

### N5. The same failure class remains at the dex level (low; not reproduced, evident from the code)

**Path.** `thesis/runner.py:147` → `thesis/market.py:339-345`. `listings()` reads every builder dex's `meta` with no isolation.

**Failure.** If one dex's `meta` fails on every pass (a broken new HIP-3 deployment, say), every acquisition of the date raises. The result is F1's original outcome: main and no-reading missed, and on a Monday "no attested snapshot" for all five benchmark markets.

**Fix.** Either record the failing dex in `failed` (its markets unavailable for the date; a benchmark market on it skipped "market read failed at the snapshot"), under the same persistence rule as N1, or name it in the revision as a known limitation. The wording below assumes the fix.

### Notes (nothing judged changes)

- **Readiness-only failure.** When only the readiness check raises (`runner.py:167-171`), the market stays in `markets` and `daily`, contrary to the build record. It then behaves like any not-ready market: shown, but not registrable. The benchmark checks `failed` first. Harmless, but it should be stated or made consistent.
- **Orphaned temporary files.** `write_atomic` (`thesis/registry.py:41-52`) leaves a `.<name>.<random>.tmp` after a SIGKILL, and these accumulate. Nothing globs for them.
- **The freeze's image.** The freeze wake-up in `PROGRESS.md` names `sha256:a2261d4c…` (`247871b`), the running prewarm's image. The freeze must be applied on an image of the head actually frozen. The old prewarm writes compatible caches but takes no flock, so no new-code writer should share the root with it. `run.lock` already keeps the runner out, and the freeze only reads.

## Checked, nothing found

- **F2.** `daemon.py:134-136` writes a response only when the stored bytes differ, through a temporary file and a rename. A truncated file from the old code is rewritten whole, which heals it.
- **F3 and the cross-process lock.**
  - Deadlock: no code path holds two `exclusive` locks, so there is no lock-order cycle. In one process, flock on separate opens also excludes threads, and the limiter's `hold` blocks only background reads, while every flock holder that waits on the venue is a foreground bars read.
  - A crashed holder: the kernel releases its flock, so it cannot wedge the lock.
  - The runner beside `thesis-report`: a waiter is delayed by at most one fetch of the other process. That delay is bounded, but `check()` cannot cancel it.
  - Old caches read unchanged.
- **The per-market rule.**
  - A failed market cannot reach main or no-reading by another path. `markets` and `prices` serve only `snapshot["markets"]` (`daemon.py:46-52`). Registration needs `ready`, which is false for it (`runner.py:117-121`). Ablations take only legs of accepted main theses.
  - Every arm reads the one attested file, failures included, so the identical-snapshot claim holds.
- **The batch.** `register_benchmark` isolates each market, and at give-up only the market still failing is "run missed". The four updated tests changed only by that intended behaviour.
- **The lower notes.** The `NOT_READY` and "main was missed" reasons, the per-comparison undefined-skill count, and the daemon closed in a `finally` are all as described. SCORING.md's two additions match `scoring.py:47` and the entry-bar contract.

## Sharded suite

`python3 ops/shards.py /home/kevin/repos/mm-rv-rf9`: 1,977 of 1,977 reported: 1,953 passed, 2 skipped, 19 xfailed, 3 failed, 0 missing (wall 666 s). The three failures are the `LOCAL_ONLY` tests that need `data/store` (`kernel/tests/cli/test_differential.py::test_kernel_matches_witness`, `reference/tests/test_differential.py::test_an_interrupted_run_resumes_where_it_stopped`, `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit`), as in the hunt, because the review worktree has no `data/` by design. Every thesis test passed.

## Criteria wording

**Do (a) and (b) as proposed loosen a frozen threshold?** No.
- C10.5's counts (20 accepted theses, four executed batches, the miss tolerance as its restatement) are unchanged.
- A main session run on a smaller market set cannot add theses in the failed market.
- A degraded session that registers nothing lowers r, which only lowers the misses tolerated.

**Do they allow a run that passes while its claim is false?**
- (a) as proposed leaves "persistent" undefined, and the code reads any single failure as persistent (N1). It also says "recorded in the attestation", which the code does not do (N4). Neither is a false pass, but each makes the text untrue of the system.
- (b) as proposed blesses the implemented classification. That classification can hide a reached call, and with a recording defect it reads `match: True` (N3, construction c). So it needs to say what may be classified refused.

I endorse the following, as a second dated revision beneath main's stage 10 revision of 2026-11-09 02:31 UTC (2026-11-08 21:31 EST), with the code made to match:

> **(a) Item 2, operational skips.** The operational reasons also include "market read failed at the snapshot". A market whose daily or hourly read or readiness check fails during acquisition, or every market of a builder dex whose listing read fails, is retried alone at each acquisition pass until D + 04:45 UTC (23:45 EST the day before), and the snapshot is not attested while such a retry is still due. A failure still present then is a persistent read failure. It is recorded with its reason in the attested snapshot and in its attestation record, listed in the C10.6 report, and makes only that market unavailable for the date: it is not shown and not ready, so no arm can register in it. Main and no-reading still run on the attested snapshot, which every arm shares, failures included. In the Monday batch the market is skipped operationally ("market read failed at the snapshot: <reason>"), so that batch is not executed. A failure of the core venue's listing read still leaves the date without an attested snapshot.

> **(b) C10.2.** The per-session mapping counts the client calls that reached the daemon. A call is refused locally, and is not a client call that must map, only when it is the only `./thesis-agent` call in its Bash command and that command's result is exactly the client's own refusal: a nonzero exit whose whole output is the usage line (an unknown command or a wrong number of arguments) or one JSON object `{"ok": false, "error": <text>}` (an unreadable FILE). No daemon reply has that form, and a call that reached the daemon exits 0. Such calls are counted per session as `refused_locally`. Every other client call maps to exactly one daemon call record by command and arguments (a FILE argument by count; an argument with a shell expansion matches any value), and every daemon call record of the session maps to exactly one client call. A call the transcript cannot attribute (a loop, a refusal beside other calls in one command, an expansion that changes the arity) fails the session's check closed.

D + 04:45 UTC (23:45 EST the day before) is a choice (N1's reason: at most one retry in flight past it, about 91 s, then local readiness and attestation, all before 05:00 UTC (00:00 EST)). Per CLAUDE.md it is stated with that reason in paper appendix T3.
