Fresh-context Opus session, 2026-10-30, independent of GPT's review beside it.

## Decision 1: `agent-real`

**Verdict:** four of the five findings are real as written. (b) names a real gap, but its fix is wrong under the frozen text. The file misses several worse paths. Nothing was edited, and my only runs were in the scratchpad.

### The five findings

| # | Real? | Evidence | Correct fix |
|---|---|---|---|
| (a) | Yes | `campaigns.py:248` writes under `REPO/audit`. `live.py:88` makes the root read-only. The write comes after the claim. | Write `work/real.json` atomically. Copy it to `audit/` on this PC from the mirror, as `agent-summary` does. |
| (b) | Gap real, fix wrong | `arm_a()` never inspects `run`. | See "Dead or partial arm A" below. |
| (c) | Yes, and broader | Pre-claim crashes also lose the attempt, because `work` refuses reruns (`:221`). | One resumable path, below. |
| (d) | Yes, but "after the release" is too late | The claim is per store (`main.rs:275`). | Append the claim to this PC's `data/holdout/spent.jsonl` after seeding and before `apply`. No code is needed, and a re-seed then fails closed. |
| (e) | Yes, cosmetic | `:223` discards `wait_for_room`'s return value. | Record the account and the windows. |

### Dead or partial arm A

The criteria already answer this for most cases: "A crash, timeout or early stop ends the arm with whatever it evaluated. A rerun would need a new, later holdout" (`criteria.md`, Harness, One attempt).

- **At least one evaluation:** it is a result. The gate runs on what exists, B runs, and the batch goes ahead. Refusing, as (b) proposes, saves nothing: A's attempt is gone, no rerun is allowed, and stage 3 deadlocks.
- **Zero evaluations (`run["spent"] == 0`):** as written this is also a result, so B alone can spend the release. I recommend a dated revision making it a **void attempt**:
  - No claim and no B.
  - The ledger and directory are kept.
  - A fresh campaign id is used, because `mirror` refuses a vanished `.jsonl`, so the directory can't be moved.
  - Nothing from the data reached the agent or the operator, so no selection channel opens.
- **No threshold or "infrastructure failure" void for partial runs:** the operator has then seen results, and that opens a stopping option.
- **If the human declines the void rule:** the frozen text stands, and B alone is reported with C3.3 qualified.

### Further ways to lose the release

| Finding | Evidence | Status |
|---|---|---|
| A zero-call session crashes the report after the claim. `daemon.log` exists only after the first call, and `audit_run` opens it unconditionally. | `daemon.py` `log`, `campaigns.py:54,241` | Read |
| `audit["match"]` is false whenever the agent has a rejected `check`, and the brief invites those ("check until it type-checks"). `mm check` writes a `reject` row that `audit_run` counts, but it counts only `eval` log lines. `test_c34` asserts `match`, so C3.1 would fail on evidence that cannot be re-produced. | `main.rs:216` `check`, `campaigns.py:55-59`, `criteria/test_stages3to5.py:19` | **Reproduced** (one row from `mm check` on a bad file) |
| One finalist's abort exits with status 1, and `holdout_run` raises. The other finalists are committed but unread, and the claim is spent. | `main.rs` `eval` (`status = 1`), `gate.py:209` | Read |
| `require_frozen_searcher()` runs after arm A's one attempt. | `campaigns.py:232` | Read |
| `mechanism_check` uses `check=True`, so a pre-claim crash burns arm A. | `gate.py` `mechanism_check` | Read |
| `real()` has no test. Only `comparison` is tested, with fake dicts. Null campaigns rarely pass SPA, so the series may never exercise a batch with finalists. | `git grep` found no caller in tests | Read |
| A frozen report item has no implementation: "Each finalist's difference on the holdout is reported too". Holdout runs pass no `--mechanism`, and `reported()` keeps whole-run exposures. It is recoverable later, since a spent holdout may be read, but it needs a reporting step or a revision. | `gate.py:206`, `main.rs:119` | Read |
| C3.4 says diagnostics are "recorded only after the promotion decisions are committed". The kernel commits them inside each holdout row, and promotions are never committed to the ledger at all. | `main.rs` `evaluate`, `:381`-area | Read |
| With zero finalists in both arms there is no claim (`gate.py:201`, and the kernel refuses an empty batch). This is plausibly the likeliest outcome. Paper §8 says the holdout is then unspent; stage 4 says stage 3 spends it. It needs a ruling and a `released: false` field. | | Read |
| Lower risk, not measured: the ledger uses the rollback journal with a 60 s busy timeout, and the 10-minute mirror backup holds a shared lock. A timeout mid-batch returns `R_LEDGER`. `usage()`'s `total_cost_usd` lookup could also raise after the claim. A report built only from the ledger makes the second recoverable. | `ledger.rs:70`, `live.py:205`, `campaigns.py:188` | Unverified |

### Simplest design

All of this lives in `campaigns.py`, `gate.py` and `cli.py`, with no kernel change:

1. **Before arm A:** run `check_frozen`, the searcher check and a writable-path check.
2. **Steps skip if done:**
   - Arm A runs only if `work/run` is absent. If it exists without `run.json`, the arm crashed and ended.
   - Then B, then both freezes.
3. **`work/pre-release.json`, written atomically before the claim:** run record, both arms' reports, mechanism results and the Holm families.
4. **Release:** skip it if `spent.jsonl` already names this campaign.
5. **One pure `report()`:** reads `pre-release.json` and the ledger only, never stdout. It is both the normal path and the recovery path.
   - A missing or aborted finalist becomes `(np.zeros(0), 0.0, None)`. I ran this: `holdout_pvalue` gives exactly 1.0, Holm keeps the full family, and `promote` needs no special case.
6. **Commit promotions:** write them to the ledger (`mm disclose`) before reading diagnostics.
7. **Fix `audit_run`:** match per kind (eval and check calls against their rows) and tolerate a missing log.
8. **Test and rehearse:**
   - A test with `run_agent` stubbed.
   - One pod rehearsal on a planted synthetic market with a read-only root, with no model call. This needs the report start as a parameter.

A kernel-level failure right after the claim stays unrecoverable. That case is reported as lost and goes to the human.

**Stakes:** the campaign is a labeled pipeline validation with near-zero power, so don't build beyond this.

### Who decides

**Dated criteria revision, reviewed before the run, and the human should approve it:**
- R1, the zero-evaluation void. It reopens the one-attempt rule. I argue it cannot change a false-discovery outcome, but the advisor shouldn't self-certify that.
- R2, C3.3's "complete" means ended under One attempt.
- R3, a missing or aborted finalist counts p = 1 inside its family. This is stricter, and valid because p = 1 is a valid p-value. C3.3's "holdout result" is then an abort record, or a human-reviewed gap.
- R4, diagnostics are computed in the batch and released only after the committed decision.
- R5, how the holdout mechanism difference is reported.
- The zero-finalists ruling.

**No revision needed, logged in `audit/decisions.md`:** (a), (c), (d), (e), the check ordering and the tests. The `audit_run` fix needs an independent review, because it measures C3.1.

**Not to do:**
- Don't change the kernel. That forks the pilot's frozen kernel.
- Don't move the running series to the new image. The `audit_run` tolerance would turn a dead session from a crash counted as a promotion into a non-crash, which loosens C3.2. Keep its digest and recompute its audits from the retained `daemon.log` and ledgers at summary time.

### `harness_hash()`

No fix touches it. It covers `brief.md`, `research.md`, `swarm.md`, `daemon.py`, `harness.py`, `sandbox/*`, the model, the limits, the tool flags and the claude store path (`harness.py:26-31`). `campaigns.py`, `gate.py` and `live.py` are outside it.

Three traps:
- Don't "fix" `daemon.log` in `daemon.py`.
- Don't add `finally` in `run_agent`.
- Don't change the flake's claude.

The new image also makes PROGRESS's `sha256:57495a64…` stale for `agent-real`. The seeded `mm` is unchanged.

---

## Decision 2: `L5_text`

**Do a dated revision in `laws-frozen.md`. The statement text stays the same, but two definitions must change. The blocker's proposal covers only one of them and would leave the law unprovable.**

### The missed problem

`Json.parse` rests on `partial def value` (`Json.lean:145`), so its duplicate-key refusal (`:158`) is invisible to proofs, and a proof must cover every parsed `Value`. `field` and `get?` read the first occurrence, while `mentions` uses `kvs.any`, which sees all of them.

I ran `program` on a `Value` with two `weight` keys, a constant then `{"input":"secret"}`. It returned `ok, nodes = 1`, so the second weight was never compiled. In a model of the opaque parser that returns this value, `InputRef` holds and the source is not required. So `L5_text` stays unprovable even with a total `mentions`. The blocker's claim that a proof "can reason conditionally" on the parser result is wrong. Reading `expr` and `program`, duplicates are the only such gap.

### The revision

1. **Make `mentions` total.** This compiles on 4.34 (scratch probe), using `kvs.attach.any fun ⟨(k, v), _⟩ => …` with `termination_by` and a short `decreasing_by`.
   - `eq_def` is available.
   - Its axioms are `propext` and `Quot.sound`, both allowed.
   - An inductive `Mentions` Prop also compiles with no axioms, as Opus-3 N1 once suggested. I prefer the Bool, because the diff shows the same traversal and it stays executable for tests.
2. **Move the duplicate rule into `check`.**
   - Add a total `Value.uniqueKeys` guard at `Syntax.lean:326`, returning `.parse`, and delete `Json.lean:158`. That keeps one home for the rule.
   - The result code is `.parse` either way, so `check` should be unchanged as a function of the text. The corpus differential confirms this.
   - Rust is untouched (`dsl.rs:317`).
   - `Main.lean:105,125` parse market files through the same parser, so apply the guard there too.
   - I found no duplicate-key test in `kernel/mm/tests` or `reference/`, so add one to the corpus.
   - Add `Json.lean` to the hash table. It is absent today, and `check` and `InputRef` both depend on it.

### Rejected options

- **A no-duplicates hypothesis on the law:** it is formally weaker (C7.7: a proof of a "weaker statement does not count") and adds an unchecked assumption.
- **`InputRef` defined from the compiled program:** the law becomes vacuous.
- **First-occurrence `mentions`:** it mimics the checker and is uglier.
- **A total parser:** it is large, and the file says parsing is outside the laws.
- **An axiom:** not allowed.

### Can it change the guarantee?

No weakening:
- `Value` has only finite terms, so the total `mentions` computes the same function by the same equations.
- `check` is meant to agree on all text.
- `required` and admission don't use `mentions`, which has no caller outside `InputRef`.
- The law gains content, since as frozen it says nothing provable. It also keeps C7.7's named test 8 and L5's "every input occurrence".

So it cannot change a false-discovery or leakage outcome. No `criteria.md` revision and no human decision are needed; log it in `audit/decisions.md`. C7.7 still requires independent review before the proof, which matches GPT queue item 7 and a fresh Claude session. Statements stay the same, but laws using `check` rebuild, and `check_wf` (`Proof/Checker.lean:94`) needs one more split.

Probe files are under `/tmp/claude-1000/-home-kevin-repos-moneymachine/9be30ecb-bd29-4442-bb2f-d4ef073ba42b/scratchpad/lean/reference/lean/` (`Probe.lean`, `Probe2.lean`).
