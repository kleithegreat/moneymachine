**The rewrite is mostly sound, but the forward-window decision is not sufficiently protective, and `93b3be0` puts the language transition in the wrong place.** There are also a few meaningful losses and misleading statements in §3.

Reviewed at `65902b2`, including comparison with `fde3564~1`. Findings below are ranked by consequence.

## 1. High: protect the forward recordings technically

**Yes, I recommend a technical lock before November’s recordings accumulate.** The frozen criterion does not explicitly mandate encryption or a particular access-control mechanism, so plaintext storage alone is not evidence of a criterion violation. But the present controls do not reliably enforce its information boundary.

### The exposed boundary

- The recorder writes full funding responses, candles and order books—not merely integrity metadata (`ingest/record.py:45–61`).
- Those records live on the cluster’s `hl` volume, are copied to `/srv/moneymachine/mirror/hl`, and independently arrive through Oracle into `data/live-oci` (`ops/live.py:28–30,182–232`; `ops/oci/pull.sh:6–14`).
- The trusted PC account can access live volumes through its deployment authority. `CLUSTER.md:35–39` explicitly acknowledges this capability. The pods use UID 1000/GID 100 (`ops/live.py:81`).
- The research agent’s sandbox is a real protection (`sandbox/session.py:100–113`). **It does not protect against the advisor, builders or consultants running outside that sandbox.** A clean worktree removes nearby data; it does not revoke access to other directories or deployment credentials.

This matters because the frozen rule expressly covers **whoever can change briefs, strategies, universes, execution assumptions or finalists**, not just the research agent (`audit/criteria.md:316–318`, retained at `336–337`). The real campaign has not run and is currently blocked (`PROGRESS.md:20,45`), so consequential selections remain ahead.

The leakage need not be a strategy’s computed return. Seeing November’s prices, funding or liquidity could influence execution assumptions, a redesign or advice subsequently supplied to research. The project already recognizes this indirect route for cost-table information (`audit/criteria.md:338–348`).

### Judgment of the October 30 decision

The entry added by `93b3be0` correctly identifies the storage locations and correctly says the forward window does not block stage 3 (`audit/decisions.md:324–327`). Its justification nevertheless fails:

- **“Research agents are already sandboxed” addresses only one class of reader.**
- **“Only confirms a promotion” is not a reason to leave it exposed:** protection must precede knowing whether a promotion exists.
- **“Reverse by adding the lock” is incomplete.** Access controls are reversible; information already learned is not.

The human genuinely delegated the decision—`ctx` leaf `[237+1]`, user message at 19:03—so this is **not an unauthorized-decision finding**. I disagree with the decision on its merits.

A suitable control would keep protected payloads unavailable to advisory/build/review processes while exposing deterministic status, sizes, hashes and permitted gap reports. It must cover **all copies and equivalent derivatives**, and ordinary sessions must not retain credentials that trivially reopen them. A separate identity, encryption with separately controlled keys, or genuine filesystem/process isolation are possible approaches. A same-owner `chmod`, read-only mount, writer lock or clean worktree is insufficient.

Keep recording and legitimate stage-10 operation running. Do not solve this by casually changing the shared, frozen research harness. Also account for overlapping information in thesis snapshots and reports (`thesis/runner.py:83–100,176–192`).

**I found exposure capability, not evidence that forbidden access has occurred.**

## 2. High: “A fork reruns what it judged” is unsafe as a blanket instruction

Added in `fde3564`, now `CLAUDE.md:49`.

Exempting frozen identities from opportunistic erasure is good. But the next sentence conflates several different recovery procedures:

- A changed stage-3 harness requires fresh **null campaign IDs** (`audit/criteria.md:351`).
- A real arm cannot simply be rerun; it needs a **new, later holdout** (`audit/criteria.md:363`).
- A thesis refreeze starts a **new forward observation window**, rather than replaying the old window as fresh evidence (`audit/criteria.md:830`; `audit/decisions.md:275–277`).
- Stage 8 explicitly requires reproduction **without reopening spent holdouts** (`audit/criteria.md:1108–1109`).

The sentence could instruct a future builder to do precisely the forbidden thing. It should distinguish reproduction checks from fresh adjudication and explicitly preserve the no-recycling rule. This is a dangerous ambiguity, not evidence that such a rerun has happened.

## 3. Medium: `93b3be0` contradicts the language plan’s ordering

The recorded plan is unequivocal:

> Stage 7 finishes as specified; the Lean/OCaml transition comes **between stages 7 and 8**.

Evidence: `audit/decisions.md:302`; correctly summarized in `CLAUDE.md:98`.

But `93b3be0` appends the transition to roadmap item **6**, saying it happens “before the next stage”—therefore **before stage 7** (`docs/whitepaper.tex:554–555`).

That is not merely wording: the paper is the source of truth for intent, and following it literally would advance the rewrite ahead of the source-language work already being implemented and frozen.

**The general revision is appropriate:** removing the permanent-Rust claim and naming Lean/OCaml matches the human’s plan. Its placement is wrong. Keep the existing stage numbers and place the intervening step after item 7. The replacement condition in §6 (`docs/whitepaper.tex:269`) should also be read subject to the new stage’s proof and other acceptance criteria—not as “corpus agreement alone authorizes replacement.”

## 4. Medium: the standing kernel-milestone red-team obligation was lost

Before the rewrite, §3 explicitly required a source-blind GPT red team **after each kernel milestone**, with successful attacks retained permanently (`fde3564~1:CLAUDE.md:90`).

The replacement describes checks named by criteria or the paper and requires independent review of consequential work (`CLAUDE.md:77–81`). **A review is not necessarily an adversarial implementation exercise.**

Existing frozen obligations survive—for example C1.2 and C7.7 (`audit/criteria.md:109,984`). Nothing currently registered was canceled. But the generic trigger disappeared, leaving future milestones, especially the not-yet-registered Lean engine, dependent on someone remembering to put it back into their criteria.

Retain that short obligation, or explicitly ensure the new engine’s criteria replace it with equivalent attack coverage.

## 5. Medium: the source-fetching rule still misdescribes authorized operation

`CLAUDE.md:85` recognizes only a permitting clause or an allowing official API. The repo also recognizes a third basis, **operator decision**:

- Implemented in `ingest/terms.py:1–11`.
- Used for Hyperliquid (`venue/sources.toml:42–74`).
- Recorded for other sources in `audit/decisions.md:146–153`.
- Recognized by the paper (`docs/whitepaper.tex:246`).

This discrepancy predates the rewrite, but the cleanup left it intact. A new session following §3 would wrongly treat already-authorized recording as blocked.

The correction should acknowledge **specific recorded human exceptions**, not imply that a structurally valid registry record proves the license permits everything.

## 6. Lower consequence: useful startup and recovery instructions disappeared

Three losses are worth distinguishing from necessary deletion:

- **Reading current status:** the old file required every session to read `PROGRESS.md`; the new startup sentence expressly addresses builders (`CLAUDE.md:27`). Advisors resuming after compaction need that obligation too—especially with the live `agent-real` blocker.
- **Missed wake-ups:** the old waiting rule explained recovery when a scheduled wake-up passed without a recorded start. The new rule only schedules it (`CLAUDE.md:92`). This matters because user timers run only while logged in (`PROGRESS.md:15`).
- **UTC/Eastern formatting:** the instruction disappeared, but its enforcement remains (`ops/commitcheck.py:1–20`; `ops/test_commitcheck.py:21–25`). Either retain a short pointer or expect avoidable failed commits.

These are operating regressions, not demonstrated statistical failures.

## Slop still in §3

- **“One home … nothing is duplicated”** (`CLAUDE.md:39`) is literally false: authoritative records legitimately have summaries elsewhere. “One authoritative home; summaries link to it” captures the useful rule.
- **“An idle host with work waiting is a bug”** (`CLAUDE.md:91`) is overabsolute given memory constraints, token pacing and homelab priorities. Throughput within measured limits is the goal, not universal CPU occupancy.
- **“Before a decision”** (`CLAUDE.md:34`) leaves the consultation scope unbounded. Preserve the owner’s two-peer requirement, but distinguish substantive advisor decisions from mechanical execution of an already-approved plan.

I would **not** classify the unusual prior-art phrase as accidental model slop: the human explicitly requested it in `ctx` leaf `[235+1]`, at 18:45.

## What is fine

- **Sections 1 and 2 remained unchanged**, as instructed.
- Removing “Nobody is watching” and restoring meaningful human involvement was correct.
- The consulting/independent-check distinction is substantially better; broad consultation must not erase source-blind checks.
- Pre-registration, append-only criteria, post-failure restrictions, human-only procedural redesign and spent-holdout protection remain.
- Naming Rust/Python as **today’s implementation**, with Lean/OCaml as the destination, is accurate.
- `0eb89c1` correctly follows the recorded account authorization and then-effective debugging allowance. The tighter debugging revision remains pending adoption (`audit/decisions.md:345–349`).
- The later strict-xfail wording preserves recorded failures rather than calling them passes.
- Removing the obsolete hard-limits section did not silently rewrite C8.7; its dated clarification preserves the frozen reference (`audit/criteria.md:1143–1144`).

No files changed, workloads started, or further reviews spawned. No restricted recordings or raw licensed rows accessed.
