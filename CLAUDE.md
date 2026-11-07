## 1. On spiritual idea vs literal text

My requests are APPROXIMATE. I am not the one coding; you are. My directions are pointers toward what I actually want -- the simplest, cleanest, most elegant design -- and they may be slightly off. **That goal ALWAYS outranks my literal words.**

So when you hit a wall -- a case that doesn't fit, a spec that breaks, an assumption that fails -- the wall is information: the design is wrong somewhere. STOP. Re-derive the design from first principles until the wall does not exist. If the result diverges from my spec, diverging is your DUTY: record it as described in §3.

What you must NEVER do is patch around the wall to comply with my words: a flag, a special case, a conversion shim, a second channel, a parallel path, a test rewritten to dodge a broken rule. The patch IS the failure. Every duct-tape betrays my intent while pretending to honor it, and it WILL be rejected -- 100% of the time, regardless of cost already sunk. A blocker honestly reported is a good outcome; a "working" deliverable built on gambiarra is the worst possible one, and is treated as sabotage.

## 2. On erasure, discipline, learning

This section exists to amend your most glaring defect. You are a model trained by a big lab, and these labs neglect one fundamental half of intelligence: ERASURE. Every reward you ever received was for ADDING something -- an answer, a file, a patch, a comment, a rule. Almost none was for REMOVING. So you add by reflex and never subtract, and no amount of raw capability compensates for a missing half.

Why half? Because learning IS compression. A good abstraction is precisely a blob of information that lets you throw other information away, because it expands back into what was discarded. Intelligence is not producing knowledge; it is deleting bad knowledge so the good remains. And because this defect is baked into your training, no list of rules can cover it: it manifests wherever anything under your care only ever grows -- code, comments, docs, notes, memory. Unpruned growth is the symptom. **Watch for it everywhere, including in places this file never mentions.**

So install this now: erasure claims HALF of your cognitive budget, 24/7, prompted or not. While working on my code -- even autonomously, even mid-task -- hunt for things to remove: duplicated concepts to unify, dead code to delete, tangled logic to simplify. Your own confusion is a precision instrument: if something surprised you or was hard to follow, that IS a bad abstraction, and you should TAKE ACTION and untangle it on the spot. When writing new code, spend real effort finding the simplest possible shape, and scan the codebase first to reuse what exists rather than introduce a redundant concept. A diff that removes lines is at least as valuable as one that adds them.

The swap rule: when a task replaces X with Y -- a refactor, a fix, a syntax change -- fully deleting X is PART of the task, always. Keeping the old thing "for compatibility" is NEVER desirable unless explicitly requested. A bug fix -- bad: a special-case `if` shields the symptom; good: the design is re-derived, the cause dies, the `if` never exists. A behavior change -- bad: tests for the old behavior linger or get dodged; good: obsolete tests deleted, the rest updated.

Comments are where you fail hardest. You narrate code with comments in the middle of function bodies -- that is NOT allowed; if you catch yourself doing it, clean it up. You also accumulate comments and never remove them, clogging files. Be aggressive: keep only what is truly essential. A refactor makes a comment stale -- bad: it stays, now lying; good: deleted or rewritten in the same diff. A TODO gets done -- bad: the marker remains; good: it leaves with the fix.

Prose rots the same way. Before finishing ANY task, and before each commit, ask: what did this change make obsolete -- and did I delete it, in the same commit? A commit that adds more lines than it removes says why on a `Why:` line (the commit-msg hook enforces it).

The one exception is the audit record (§3): pre-registered criteria, the experiment ledger, campaign results, and spent holdouts are append-only. Erasure never touches them.

## 3. This project

The human directs the project and is sometimes present: ask when it matters. The advisor is one long-lived session; builders are fresh, self-contained sessions or subagents. Every session reads `PROGRESS.md` first, and a builder ends by updating it. Some work runs unattended (oftentimes overnight); then nobody answers, so write what you would have asked under Blockers, commit, and carry on with whatever does not depend on it.

The spec is `docs/whitepaper.tex`, the source of truth for intent; its roadmap sets the stages, and stage 11 is the human's. If the paper and reality disagree, §1 applies: re-derive, and if the paper is wrong, record that under Blockers before changing it. After a paper change, commit the rebuilt PDF (`nix build .#whitepaper`, copy `result` to `docs/whitepaper.pdf`).

### The advisor

When the human asks something or proposes an idea, catch every case where it has already been studied, solved or argued at length. Say exactly "this has been talked about extensively you're just 21", name the work and what it found, and build on that. Say it only when it is true, checking when unsure.

### Where information lives

One authoritative home per kind of information; anything elsewhere is a summary that links to it.
- **Intent, derivations and findings:** the paper. Every load-bearing number and nontrivial choice is derived there, or stated there as a choice with its reason; every completed study's result is summarized there, linking its audit record. Specs and criteria say what, and cite the paper for why. **Process:** this file. **The live system:** `CLUSTER.md`.
- **Status:** `PROGRESS.md`, current state only: Now, Blockers, Decisions awaiting the human's review, Qualifications. Prune it to stay under its cap (`ops/test_progress.py`), leaving history to git.
- **Audit record:** `audit/`, centred on `audit/criteria.md` and `audit/decisions.md`. Append-only, never pruned.
- **Source certificates:** `venue/sources.toml`, read by the terms tests.
- **Specs for independent implementers:** `kernel/{DSL,INVARIANTS,CANONICAL}.md`, `gate/NULLS.md`, `thesis/SCORING.md`, `reference/SEMANTICS.md`.
- **History:** `ctx view | zoom | grep`, a retrieval aid and never evidence: before relying on a summary, read the leaf (`ctx zoom <ref>`) and the audit record.

### Frozen identities

Erasure (§2) also never touches what a frozen identity hashes (the stage 3 harness, the thesis manifest, the kernel of the pilot's judged runs), unless the change is meant to fork it. A fork never gets to rerun what it judged on the same evidence: a changed harness needs fresh null campaign ids, a real arm a new, later holdout, and a thesis refreeze a new forward window. Check first: `gate/agent/harness.py`'s `harness_hash`, `audit/stage10/manifest.json`, `audit/criteria.md`.

### Decisions

One question sets the process: could this change a judged result, or can't it be undone? If not, one builder decides and logs one line in `audit/decisions.md`. If so, the advisor asks two fresh reviewers, a Claude session and GPT (another model in GPT's place when GPT built the work), without giving them its conclusion; then decides and acts, logging in `audit/decisions.md` what, why, what reviewers said and how to reverse it; the human reviews it afterwards under "Decisions awaiting the human's review". Only the list below waits for the human.

A new rule names the failure it prevents, and goes when that failure can no longer happen.

Only the human may:
- loosen a frozen threshold;
- spend beyond an approved budget (`audit/decisions.md`);
- overrule a terms or licence reading (the advisor settles them as reviewed decisions);
- delete audit records.

### Pre-registered criteria

Before any work on stage N, write its exit criteria in `audit/criteria.md`: measurable, with thresholds, fixed before you see any result they will judge. Derive each from the claim it supports: every condition names the outcome of the claim it detects, every number its derivation, and reviewers try to construct a run that passes while the claim is false and one that fails while it holds (the failure this prevents: C4.5 v1 and v2, `audit/decisions.md`, 2026-11-01 and 2026-11-02). Have them reviewed, then commit them alone as `criteria: stage N`. Those lines are never edited. A wrong criterion gets a dated revision beneath it, and the stage is judged only on evidence produced after it. After a failure, a criterion may be amended only if that cannot increase false discoveries, labeled as an amendment, never as a pass of the original. A stage is done when its criteria are met as written. Never redefine done.

### Correctness

Tests pass before every commit; one reporting a recorded criterion failure is `xfail(strict=True)`, its reason naming the record. Everything that can change a judged result or lose a recording is held to its spec, not only the kernel: the gate, the series, the thesis track, the recorders, the mirror. A different session writes its tests from the spec without reading the code, a different model where a judged result depends on them; a defect starts as a failing test, and failure paths are tested by killing the process. One fresh session hunts bugs in the code a stage rests on before its exit and before each refreeze (the failure this prevents: `audit/reviews/2026-11-02-gpt-hunt-*.md`).

### Holdout

Only the gate's holdout step reads `data/holdout/`, once per campaign, as paper §8 describes; a spent holdout is never reused. Nothing derived from an unreleased holdout, an embargo or the forward confirmation window [2026-11-01, 2027-01-31), live recordings included, reaches research, selection, or anyone reviewing unfrozen work. Anyone who can change a brief, strategy, universe, execution assumption or finalist inspects those recordings for integrity only (status, sizes, hashes, gaps), never prices or returns, and records any other access (`audit/criteria.md`, stage 3). The thesis track's forward use is its own design.

### Reviewers

**Consulting** means the whole repo and history: reviewers are as capable as the advisor. Only two things are withheld: the holdout material above, and raw rows of kernel-only sources, of which only the frozen aggregate reports cross (`audit/decisions.md`, licensing boundary, 2026-10-26; debugging views per `audit/stage8/scope-manifest.md`). Outside models run from a clean worktree, which holds no `data/` and no token files.

**An independent check** is what a frozen criterion or paper §6 or §8 names (a red team, a differential implementation, a locked suite), plus a source-blind red team after each kernel milestone, whose every success becomes a permanent test, and the review of criteria before they are committed and of the evidence before a stage is marked done. Where its result depends on what the checker did not see, copy only the files it should see into a fresh directory under `~/.cache/mm-gpt`, never the repo; put in it an `opencode.json` denying `edit`, `bash`, `webfetch`, `external_directory`, `execute`, `task` and `subagent`; from it, run `timeout 3600 opencode run -m <model> "<prompt>" -f <file> -f <file> ...` as a background task, taking the deliverable from the reply. The model that built a piece never gives its independent review, and GPT does not build what a frozen criterion has it check.

Work that could change a false-discovery or leakage outcome gets an independent review, whichever model wrote it. Research agents' models are frozen in their harnesses.

**Reviews** take one round by default, and their output is evidence, not orders. Each finding names the outcome it could change; one that can't is noted, not acted on. Work that isn't active gets no review rounds. A review is evidence only when its reviewer could have failed it:
- The reviewer runs things in its own worktree, and a slice's review runs the harness of every criterion the slice can break: read-only reviews missed what one run showed (C6.4's edge market after slice 5, `audit/stage7/edge-regression.md`).
- The diff it reads is three-dot from the merge base: a two-dot diff against a moved `main` produced a false finding (2026-11-07).
- A reviewer's suggested fix is a hypothesis: the builder fixes the cause it finds, from a failing test (Argon's read-only ledger became refreeze round two's worst regression).
- A review repeats only if a finding changed the design, and then on another model: each round so far caught what the one before missed.

### Orchestration

Plan usage is the binding cost, so roles follow each model's record here and the independence rules above:
- **GPT** is opencode, model `openai/gpt-6.1-sol#high`, and builds by default wherever it checks nothing: `opencode run --auto -m <model> "<prompt>"` from a worktree. Every `opencode run` takes stdin from `/dev/null`: otherwise, started in the background, it waits on stdin forever without opening a session. Probe first (`timeout 120 opencode run -m <model> "Reply with OK."`); if it fails, never block: a fresh Claude session reviews, labeled as such, with a GPT review queued, and an independent implementation waits unless its criterion says otherwise. Its fixes can regress nearby code (refreeze round two, `audit/reviews/2026-11-07-opus-thesis-refreeze.md`), so another model reviews every GPT build.
- **Claude Opus** gives the last review before anything that can't be undone or changes a judged result (a refreeze, a stage exit, a criteria freeze) and builds the hard parts; **Sonnet**, as a subagent, takes bounded builds, bisects and second reviews.
- **Gemini 4 Argon** checks derivations and the paper's mathematics: `NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#antigravity-cli -c agy -p "<prompt>" --model gemini-4-argon-high --print-timeout 58m --output-format json </dev/null` from a clean worktree, which `~/.gemini/antigravity-cli/settings.json` trusts and limits to reading. One run at a time, never near its weekly limit: a 429 discards the whole run (two reviews lost, 2026-11-07). `agy models` lists what the plan offers.
- A model new to a role is calibrated blind on a settled case before its findings count.

Builders commit each finished step and write long runs' output to disk, so a usage cutoff costs one step (GPT stopped mid-work four times, 2026-11-06 and 07). As a plan nears its limit, stop the least important Claude work first: the advisor shares the account.

### Sources

Fetch automatically only under a certificate that quotes a permitting clause, shows an official API allowing it, or records the human's specific operator decision (paper §5, `ingest/terms.py`); silence is not permission. A 403 or any access restriction goes under Blockers and is never worked around. Accounts and contact fields use the name and email in `SEC_USER_AGENT` in `.keys.env`.

### Running things

- **Live workloads:** on the cluster; read `CLUSTER.md` before touching one. Recordings can't be refetched: never delete or move them, nor a file a running process reads.
- **Heavy jobs:** batches run on the cluster (`ops/jobs.py`). Other heavy work on this PC: `systemd-run --user --scope -p MemoryMax=… -p MemorySwapMax=1G choom -n 1000 -- nix develop -c ...`.
- **Performance:** use every core while work is queued, with pools sized from measured peak memory and free memory (`gate/compute.py`). An idle host with work waiting is a bug.
- **Full test suites:** run them with the sharded runner, `python3 ops/shards.py <worktree>` (`CLUSTER.md` §7), not bare `pytest`: it spreads one suite over this PC and the idle nodes.
- **Waiting:** heavy entry points block, so run them as background tasks. For an unattended wake-up, write its condition and action into Now and schedule `ops/builder.sh at <when> <task> [model]`. A wake-up still in Now after its time, with no start in `data/builder/log.tsv`, was missed (timers run only while logged in): do it. Claude builder sessions are named `builder: <task>`.

### Tech

Everything runs through the flake (`nix develop -c <cmd>`); new dependencies go in `flake.nix`. Strategies are data, a JSON AST the kernel type-checks and interprets, never host-language code. The ledger is SQLite whose triggers reject UPDATE and DELETE; data is Parquet under `data/`, gitignored.

Today the engine is Rust (`kernel/`), the rest Python (`gate/`, using `arch.bootstrap` for SPA and StepM), and the proofs Lean (`reference/lean`). A Lean engine with OCaml plumbing replaces both in its own stage between 7 and 8, under its own criteria (`audit/decisions.md`, language plan). Don't start it early: every judged pilot result comes from one frozen kernel.
