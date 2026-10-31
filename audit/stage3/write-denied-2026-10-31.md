# C3.2 v2: the agent's Write tool is denied (2026-10-31 09:25 UTC, 05:25 EDT)

Found by the advisor while confirming v2's first campaigns reached a model session. Integrity inspection only: null markets, no holdout or real data.

## What the campaigns show

The first nine v2 campaigns (`agent-null-2-N2-0` to `-8`, mirror `agent/`, as of 09:22 UTC (05:22 EDT)) each ended `stopped: finished`, exit 0, `spent: 0` of 100 evaluations, with every Write call in the result line's `permission_denials` (1 to 5 per campaign), plus Bash commands outside `./mm-agent`. The agents read the brief, ran `./mm-agent budget` and `history`, wrote a strategy with the Write tool, were denied, and stopped to ask for permissions. No `mm eval` reached the daemon. Each row counts as a non-promotion.

The series ended by 09:55 UTC (05:55 EDT; Job `agent-series` Complete): 20 rows, no crash, `spent: 0` in every run record, no promotion; 1 counted promotion, `agent-null-2-N2-17`, whose agent made no daemon call (`gate/agent/campaigns.py` `agent_null`). As written, v2 reads 1 of 20, within 2.

## Cause

`sandbox/session.py` `tools()` grants file writes with `--allowedTools ... Write(//work/**)` under `--permission-mode dontAsk`. Under the pinned CLI, claude-code 2.1.304 (pinned 2026-10-28, `5c1d4c3`, which refroze the harness as a successor), that rule does not permit the Write tool; Edit rules govern file writes.

- The local dry run of 2026-10-19 (`data/stage3/c32-N2-dryrun-2`, CLI 2.1.301, same rule) shows 5 Write calls and no Write denial. v2's transcripts show 2.1.304, `dontAsk`.
- Reproduced on this PC (`nix develop`, 2.1.304, the frozen `sandbox_command`, model haiku, one prompt asking for a Write to `/work/probe.txt`): frozen flags, file not created, Write denied; frozen flags without `Edit` in `--disallowedTools`, same; frozen flags plus `Edit(//work/**)` in `--allowedTools`, file created, no denial.

No real session ran between the pin and v2, so the refreeze did not exercise the permission set; no test runs a real session.

## Consequences

- Under this harness no arm A session can evaluate a strategy: every C3.2 campaign is a clean zero-evaluation run, and every real attempt would be void (the void-attempt revision of 2026-10-31 00:05 UTC (2026-10-30 20:05 EDT)).
- `harness_hash` and every session identity hash `sandbox/session.py` and the `claude` store path, so changing either forks stage 3's harness (fresh C3.2 ids, `audit/criteria.md` line on the harness) and stage 10's track identity (`audit/stage10/manifest.json`).
- Stage 10 is hit too (corrected 09:30 UTC (05:30 EDT), after GPT's consult; integrity only: ledger row counts and transcript tool metadata, no forecast or content). `./thesis-agent register FILE` needs a written file. The track's 12 agent sessions since its freeze (`mirror/thesis/sessions/`, 6 `main`, 6 `noread`) all ran 2.1.304; 4 `noread` sessions called Write and were denied; the ledger holds 61 `main` and 32 `noread` client calls and no thesis registration from either agent, only the benchmark's 4. C10.5's window has accrued no agent registration.

## Correction, 10:15 UTC (06:15 EDT), after the fresh Claude consult (`audit/reviews/2026-10-31-claude-write-denied.md`), checked by the advisor

- The CLI moved before the pin: this PC's thesis sessions of 10-26 to 10-28 (`data/thesis/sessions/`) already report 2.1.304. The change happened between the 10-19 dry run (2.1.301) and 10-26; the 10-28 pin froze it.
- Six of the mirror's twelve session directories are from before the track's freeze (2026-10-29 01:25 UTC (2026-10-28 21:25 EDT)). Since the freeze, `thesis-62476ec60a1b` ran 3 `main` and 3 `noread` sessions, with 27 and 14 client calls and no registration. The 61 and 32 calls above span three track versions. No agent of any version (`95bf…`, `ca50…`, `6247…`) has a thesis row; only the benchmark's 4, under `95bf…` and `ca50…`.
