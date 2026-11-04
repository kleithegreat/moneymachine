# agent-real: ways it can spend the holdout without a valid result

Found 2026-10-30 (preparing its cluster workload; `gate/agent/campaigns.py` `real`, `kernel/mm/src/main.rs` `claim_holdout`). The claim is appended to `<holdout store>/spent.jsonl` before anything is evaluated and is never undone.


Redesign:

- (a) the report is written to `audit/stage3/real.json` after `holdout_run` claims `spent.jsonl`, and the pod's root is read-only: write it under `work/` (mirrored), then copy it;
- (b) arm A's run is unchecked, so a dead session (rate limit, auth) lets B alone spend the joint release: refuse unless A exited cleanly with evaluations spent, before any claim;
- (c) a crash after the claim leaves ledger results, no report, and a `work` that refuses reruns: rebuild the report from the ledger;
- (d) the claim is per store, and this PC's `data/holdout` never sees the cluster's: append it there after the release;
- (e) the account that ran is not recorded.

Closed 2026-10-31 by `audit/criteria.md`'s revisions of that date and `gate/agent/campaigns.py` `real` (tests: `gate/tests/test_agent_real.py`). Remedy (b) was replaced: arm A's exit does not block the release, only zero evaluations (void) or a failed audit. Remedy (d) moved before the apply (`CLUSTER.md` §2).
