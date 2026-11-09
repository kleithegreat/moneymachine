# Round fifteen handoff (delete when round fifteen lands)

The builder paused on 2026-11-09 at about 20:45 UTC (15:45 EST), when the human paused the work. Scope: Argon's review of rounds thirteen and fourteen (`audit/reviews/2026-11-09-argon-web-refreeze-rounds13-14.md` on `main`). Code only; the wordings, T3 and the paper are left to the architect. No file covered by `harness_hash()` may change; it is `6a335714…` before and after.

**Done, each from a failing test** (`thesis/tests/test_refreeze_round15.py`):
- **D2** (`9ef5161`): `unbenchmarkable` checks listing status before failures. `scope_of` is the one rule for what a snapshot reads.
- **D4** (`c894f2c`): the draft is saved atomically when it is created and after every update, and daily bars are kept as soon as they are read. A save costs about 0.2 s for 9 MB. "An attempt in flight finishes" now means a request admitted before 04:45 UTC (23:45 EST) may finish; a further page or request of that attempt is cancelled and the failure is final. The paper's sentence needs that qualifier.
- **D5** (`c894f2c`): the core listing and the builder-dex list are read and kept separately; `listed_at` is `{source: read time}`, with `""` for the core venue.

**Left:**
1. **D1 and D3, thesis-only, in `thesis/harness.py`.** The audit fails if:
   - any line fails to parse;
   - the transcript has no `system/init` event;
   - it does not end with `result`;
   - any content-block type is outside an allowlist. Seen in the 46 recorded sessions: `text`, `thinking`, `tool_use`, `tool_result`, `fallback` (31 times); probably also `redacted_thinking`.

   A tool outside PERMITTED counts unless the call is in `permission_denials` or the tool is absent from init's `tools`, which proves it never executed (N2-8's `Edit`: "No such tool available").

   Tests to add: `server_tool_use`, `mcp_tool_use`, a torn final line naming WebFetch, and replacements for the round-14 tests that hand-build transcripts.

   Facts and open points:
   - All 46 recorded transcripts parse and end with `result`, so honest sessions failed this rule 0 of 46 times.
   - Test whether the CLI dies with the runner (bwrap `--die-with-parent`).
   - The report fails C10.2 while any session lacks a `session_end`. It must not close sessions itself, because it can run beside a live runner.
2. **Guarantee 1: a crash between a command's ledger rows and its call record.** `mm disclose` commits one row per run, and a two-row transaction would fork the kernel's identity. So the design is one row per call:
   - an effectful call's effect row (`thesis`, `exit`, `ablation`) carries its call record under a `call` key;
   - `registry.register` takes a callback that writes the response and returns the call fields;
   - a new `Ledger.calls()` reads call records across those kinds;
   - `theses()` and `exits()` leave the key out.
3. **Guarantee 1: `fetch`.** Store the raw body under `responses/` by its `body_sha256` before the record commits. Add `fetch` to `test_record_before_reply.py`.
4. **The full suite:** `python3 ops/shards.py /home/kevin/repos/mm-r15`. The whole of `thesis/tests` passed (1,039 tests) before the builder's last test edit.
