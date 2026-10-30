# Draft: scope manifest revision 2026-10-30 (answers GPT's third review, B1 and B3-B5)

Status: DRAFT, not committed into `scope-manifest.md`. It becomes a dated revision only after GPT reviews this
draft (usage limit pending as of 19:41 UTC, 15:41 EDT) and before any affected evidence is inspected. Written from
the repo's text alone (manifest, `exposure.md`, criteria, `decisions.md`); no vendor row, count beyond those already
in the ledger, or hash was read; nothing pulled or spent.

## Evaluation of `manifest-review-gpt-3.md`

GPT's verdict ("not yet sufficient to authorize research use") is correct and stays true: no class is admitted. Each
finding below is judged on its own.

### B1 (exposure): partly right; fix is cheap and narrowing

- *Omitted thesis-agent reads.* Right. The ledger says it omits them; an annex cannot place exposure it has not
  seen. The overlap is a leakage matter (an agent that saw a series may influence a stage 8 choice), so it is not a
  known limitation. Fix: the inventory is a prerequisite of the first annex, and it incorporates the thesis series'
  own ledger (every read recorded there) by artifact and interval.
- *Search/spent does not retroactively satisfy prospective freezes.* Right as a statement, and it changes nothing
  that has happened. Evidence from the repo: the manifest's ECB population and 750-date rule were committed
  2026-10-23 14:24 EDT (`c2b0811`); the first ledger row is 14:25 EDT; the 10-26 revisions state the ECB rule
  "stands unchanged". So no frozen selection choice is known to follow exposure. The annex's own choices (window,
  decision cadence, resolver) are not yet made, so they are the ones at risk. Fix: say so, and make the annex certify
  it.
- *Indirect and cross-source overlap.* Right in principle (the ledger's strict-reading list of catalog listings
  already hints at it); the inventory rule covers it by naming it.

### B3, B4 (permission timing): half right

- *Stale pointer.* Verified: the manifest says AI-facing outputs await the human's determination "in
  `PROGRESS.md`, decisions awaiting review", but that section reads "None" and `audit/decisions.md` records the
  human's decision of 2026-10-26 17:25 UTC (13:25 EDT): kernel-only role, the permitted report list, no vendor
  permission requests, the human accepts this reading of the terms. The manifest must cite the decision, not an
  empty queue. This is a real inconsistency, fixed below.
- *"Human ownership is not authorization."* GPT is right that a pending question authorizes nothing, but the
  question is not pending: the human decided it. What remains is GPT's claim that the reading may be wrong (CME
  Schedule 5 and DS-45 "metadata" and "generating output"). That is a terms-risk judgment the human has accepted
  and cannot change any false-discovery or leakage outcome. It was raised in all three reviews. Per CLAUDE.md's
  third-rejection test: **record it as a known limitation** (proposed text below), not as a further gate.
- *Gate before each operation, recording conditional on rights.* Costless and consistent with the existing rules, so
  adopt it: it is a restatement of what already holds (certificate before fetch), narrowing nothing the human
  approved. Operations are separated into covered and not yet covered.

### B5 (debugging allowance): right on leakage, wrong to block outright

Raised three times, and it can affect leakage: a coding session that sees rows can later shape a campaign. The
remedy is not new discretion but a narrower rule. Fix: the allowance stops being "small amounts" in general.
Before an annex: the criteria's integrity list only (already so). After: schemas, counts, hashes, test results;
row samples only from agent-readable sources, only from search periods, each logged in `exposure.md`; none from a
kernel-only source (the human's "prefer counts" becomes "only counts", a narrowing, reversible by the human).
C8.6 is stated expressly. GPT's demand to block the whole debugging route until a contractual determination exists
is rejected: for kernel-only sources the narrowed rule already shows nothing GPT's concern covers, and for
agent-readable sources the grant is quoted in the record.

## Proposed manifest text (append as a dated revision)

> ## Revision 2026-10-30: answers to GPT's third review (B1, B3 to B5)
>
> Each change narrows what this manifest authorizes; none widens it. Nothing is admitted.
>
> - **Exposure inventory before affected selection** (B1). Before the first class annex, and before any selection
>   it could influence (source, population, feature, window, transformation), `audit/stage8/exposure.md` is
>   completed and frozen as a campaign-relevant inventory. It incorporates every read recorded in the stage 10
>   thesis series' ledger and every other recipient (sessions, subagents, GPT runs), by artifact, interval and
>   recipient, and traces indirect disclosures (a registry, a prompt attachment, a summary) and overlaps across
>   sources. Without that inventory a class stays annex blocked.
> - **Placement is not a prospective freeze** (B1). Placing exposed evidence as search or spent keeps freshness
>   accounting honest; it does not satisfy any requirement that a choice precede inspection. Each annex lists which
>   of its choices were made after exposure to evidence bearing on them, and the claims so blocked. As of this
>   revision no manifest choice is known to follow its exposure (the ECB population and rule were committed
>   2026-10-23 14:24 EDT, before the first ledger row at 14:25 EDT, and unchanged since); the annex must confirm
>   this against the frozen inventory.
> - **Permission before each operation, not only before admission** (B3, B4). Recording authorization is conditional
>   on acquisition and storage rights established by the source's certificate or permissions record before the
>   fetch. Every later operation (deterministic transformation, generator fitting and calibration, kernel
>   evaluation, any report shown to an agent or reviewer, retention after termination) needs its applicable
>   source-specific permission first. Covered today: acquisition, storage and deterministic kernel processing, by
>   the certificates and the operator's certification of Databento (2026-10-26). Not covered, so not done:
>   reports shown to any agent or reviewer (none may exist until an annex freezes their schema, within the human's
>   decision of 2026-10-26 17:25 UTC, `audit/decisions.md`), and retention of vendor-derived artifacts after
>   termination. If a source's terms prohibit an intended operation and no permission will be sought, the
>   operation is excluded. This replaces the pointer to "decisions awaiting review", which is empty: the
>   human decided the AI-output question on 2026-10-26.
> - **Disclosure to coding sessions** (B5). The debugging allowance is replaced. Before an annex freezes: the
>   criteria's integrity list only. After: schemas, counts, hashes and test results; row samples only from
>   agent-readable sources and only from search periods, each logged in `exposure.md`; never from a kernel-only
>   source. Nothing derived from a holdout reaches the research process, including integrity checks (C8.6).

## Proposed known-limitation entry (for review, then `audit/decisions.md` after the human's)

CME and Nasdaq-originated terms may restrict "metadata" and "generating output" in ways the human's reading does
not. The human accepted the reading on 2026-10-26 and made no permission requests. This is a terms risk, not a
statistical one: it cannot change a false-discovery or leakage outcome, because kernel-only rows never reach
agents and the report whitelist is frozen per annex. If a vendor objects, the remedy is deleting that source's rows
and results, which the manifest already treats as possible (audit record independent of vendor rows).

## Needs the human

- Whether the narrowed debugging rule (no row samples from kernel-only sources, ever) is acceptable; it tightens
  the human's 2026-10-26 allowance. Reversible.
- Whether to accept the known-limitation entry above as the closing of the B3/B4 terms question.
