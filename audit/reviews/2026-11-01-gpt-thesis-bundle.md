# GPT consult and review: the thesis bundle and whether to refreeze now (2026-11-01 03:40 UTC, 2026-10-31 23:40 EDT)

GPT (opencode `openai/gpt-6.1-sol#high`), read only, from a clean worktree at `thesis-bundle` (`3d7230d`), without the advisor's conclusion. Its reply from its verdict, verbatim:

## A — WITH CHANGES

The core fixes are small and technically sound: certifi retains certificate and hostname verification; robots redirects retain URL checks, public-address validation and pinned connections; directories become version-specific while ledger queries already isolate versions; the second deadline check prevents starting yesterday’s session. No new leakage or cross-version pooling path found.

**Findings, ranked:**

1. **High — crash accounting remains incomplete (pre-existing).** `thesis/runner.py:123–130,175–186,271`: after recording a main-session start, an exception can leave neither an end record nor a missed record for the due no-reading session. Subsequent scheduling skips the date because main started. `thesis/report.py:80–81` lists only ended and explicitly missed sessions, hiding these unmatched starts. **Outcome:** incomplete C10.5 evidence can appear complete under C10.6. Reconcile started-but-unended sessions and outstanding due sessions without rerunning consumed attempts; expose them in reports. Add an exception-path regression.

2. **Medium — the post-snapshot guard omits SIGTERM.** `thesis/runner.py:171–175`: a stop received during the 1.5-hour snapshot still permits main to start, contrary to `day`’s stated pre-main stop semantics. **Outcome:** an operator stop can consume a date and generate registrations unexpectedly. Recheck `self.stop` before starting main, preserving the existing distinction between a pre-main stop and an expired day.

3. **Medium — the new gate is diagnostic, not proof of working retrieval.** `ops/live.py:279–284,313–319`: it records HTTPS robots status only; a `200` can prohibit every document, and exceptions/status failures do not fail the gate. It also never exercises HTTP→HTTPS or the public `fetch` path. **Outcome:** another non-reading deployment can receive an apparently successful gate. Keep the diagnostic, but require a certified, robots-permitted document fetch through `Fetcher.fetch` in the actual image before deployment; record unavailable hosts honestly.

4. **Medium — robots rate limiting permits access (pre-existing).** `thesis/retrieval.py:163–166`: robots `429` falls into `allow_all`. **Outcome:** a rate-limit restriction permits document retrieval rather than failing closed, weakening C10.2/politeness. Distinguish absent robots from explicit throttling/access restrictions; test `429`.

The direct dependency on certifi should also be declared in `flake.nix:11–33`, rather than relying on httpx’s transitive dependency.

## B — Refreeze promptly after corrections and pod verification

Do **not** keep the broken track running merely to preserve its observation clock. Twenty-seven refused fetches establish an operational defect, not useful reading-versus-no-reading evidence. Failed-fetch main sessions are not equivalent to the no-reading control: their instructions and consumed turns differ.

Freeze one corrected bundle, record the actual new freeze, and restart C10.5’s entire 28-day window. Earlier versions cannot supply its registration, benchmark or resolved-thesis counts. If the new first window misses its requirements, report that honestly; continuing later supplies the explicitly permitted resolved-thesis requirement, not replacement registration-window evidence.

Preserve every earlier version, failed retrieval, empty session and unmatched start. C10.6 should enumerate the versions and explain abandonment using the integrity findings—not forecast performance. Never pool versions or backfill registrations. Continue necessary resolution/accounting for any earlier accepted theses.

This costs elapsed time but restores the paper’s intended comparison. Reports remain descriptive under the frozen no-claim rule.

Static review only; no files edited or tests run.
