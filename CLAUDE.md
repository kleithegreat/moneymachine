## 1. On spiritual idea vs literal text

My requests are APPROXIMATE. I am not the one coding; you are. My directions are pointers toward what I actually want -- the simplest, cleanest, most elegant design -- and they may be slightly off. **That goal ALWAYS outranks my literal words.**

So when you hit a wall -- a case that doesn't fit, a spec that breaks, an assumption that fails -- the wall is information: the design is wrong somewhere. STOP. Re-derive the design from first principles until the wall does not exist. If the result diverges from my spec, diverging is your DUTY: record it as described in §3.

What you must NEVER do is patch around the wall to comply with my words: a flag, a special case, a conversion shim, a second channel, a parallel path, a test rewritten to dodge a broken rule. The patch IS the failure. Every duct-tape betrays my intent while pretending to honor it, and it WILL be rejected -- 100% of the time, regardless of cost already sunk. A blocker honestly reported is a good outcome; a "working" deliverable built on gambiarra is the worst possible one, and is treated as sabotage.

## 2. On erasure, discipline, learning

This section exists to amend your most glaring defect. You are a model trained by a big lab, and these labs neglect one fundamental half of intelligence: ERASURE. Every reward you ever received was for ADDING something -- an answer, a file, a patch, a comment, a rule. Almost none was for REMOVING. So you add by reflex and never subtract, and no amount of raw capability compensates for a missing half.

Why half? Because learning IS compression. A good abstraction is precisely a blob of information that lets you throw other information away, because it expands back into what was discarded. Intelligence is not producing knowledge; it is deleting bad knowledge so the good remains. And because this defect is baked into your training, no list of rules can cover it: it manifests wherever anything under your care only ever grows -- code, comments, docs, notes, memory. Unpruned growth is the symptom. **Watch for it everywhere, including in places this file never mentions.**

So install this now: every task includes its erasure, prompted or not. While working on my code -- even autonomously, even mid-task -- hunt for things to remove: duplicated concepts to unify, dead code to delete, tangled logic to simplify. Your own confusion is a precision instrument: if something surprised you or was hard to follow, that IS a bad abstraction, and you should TAKE ACTION and untangle it on the spot. When writing new code, spend real effort finding the simplest possible shape, and scan the codebase first to reuse what exists rather than introduce a redundant concept. A diff that removes lines is at least as valuable as one that adds them.

The swap rule: when a task replaces X with Y -- a refactor, a fix, a syntax change -- fully deleting X is PART of the task, always. Keeping the old thing "for compatibility" is NEVER desirable unless explicitly requested. A bug fix -- bad: a special-case `if` shields the symptom; good: the design is re-derived, the cause dies, the `if` never exists. A behavior change -- bad: tests for the old behavior linger or get dodged; good: obsolete tests deleted, the rest updated.

Comments are where you fail hardest. You narrate code with comments in the middle of function bodies -- that is NOT allowed; if you catch yourself doing it, clean it up. You also accumulate comments and never remove them, clogging files. Be aggressive: keep only what is truly essential. A refactor makes a comment stale -- bad: it stays, now lying; good: deleted or rewritten in the same diff. A TODO gets done -- bad: the marker remains; good: it leaves with the fix.

Write for the reader. Erasure removes concepts, not whitespace: a dense line is not a simpler design, and packing several steps into one hides the bugs reviewers are there to find. Name intermediate values instead of nesting expressions, keep one idea per line, and never put a side effect in a comprehension. Names and types say what the code does; a docstring adds only what they cannot: the contract it implements, cited rather than restated; an invariant invisible locally (units, ordering, crash safety); the reason for a non-obvious choice, pointing to its derivation. Every Python function is fully annotated and passes `mypy --strict`, and `ruff format` and `ruff check` own mechanical style, both enforced by tests; code a frozen identity hashes joins at its next fork. OCaml is `ocamlformat`'s (`janestreet` profile) and `ppx_js_style`'s, with every warning an error; Lean builds with `warningAsError`; all enforced by flake checks. Matches are exhaustive, no handler catches every exception (`with _ ->`), no `Obj.magic`, and no warning is silenced to pass a build.

Prose rots the same way. Before finishing ANY task, and before each commit, ask: what did this change make obsolete -- and did I delete it, in the same commit?

The one exception is the audit record (§3): pre-registered criteria, the experiment ledger, campaign results, and spent holdouts are append-only. Erasure never touches them.

## 3. This project

`moneymachine` is an open, polyglot **Unified Multi-Modal Quantitative Data Fabric & Agentic Quant Experiment Platform** (architecture: `docs/quantitative_multi_modal_data_fabric_architecture.md`; source playbook: `docs/Data Fabric Source Implementation.pdf`). Start at `wiki/index.md` (or serve locally via `nix run .#wiki`), `PROGRESS.md`, `AGENTS.md`, `wiki/quirks.md`, `wiki/adrs/index.md`, `pods/README.md`, and `audit/decisions.md`. There is intentionally no root `README.md`.

### Mission & Research Posture

- **Open hypothesis generation:** Think like a curious junior researcher who assumes discoverable structure exists across macro revisions, corporate/clinical filings, spatial streams, prediction markets, and order-book microstructure until clean out-of-sample evidence settles each question. Never artificially narrow project scope or kill exploration prematurely before testing.
- **Causal discipline:** Exploration freedom rests on non-negotiable bitemporal integrity across `fabric/`: `known_at <= as_of`, `OBS` vs `FCST` polarity separation, non-resurrecting `RETRACTED` revisions, content-addressable `raw_hash` provenance, optional blinded `PodView` isolation, and forward-only scoring in `fabric/ledger.py`.
- **Plug-in subprojects:** Prior verified microstructure and execution work lives under `subprojects/confirmation-wall/` (`kernel2/` A18 Bar Markets, `reference/lean/`, `kernel-v1/`, linked with `docs/findings.md` and `docs/whitepaper.pdf`) and plugs into the fabric via `fabric/adapters/kernel2_pod.py` alongside live collectors (`recorder/` and `ingest/`).

### Pragmatic Licensing

- `ingest/terms.py` (`license_class`, `allowlist`, `admits`) and `fabric/manifest.py` (`SourceManifest.license_class`) classify source terms as descriptive metadata (`PUBLIC_DOMAIN`, `CC_BY`, `PERSONAL_RESEARCH`, `NON_COMMERCIAL`, `COMMERCIAL_API`, `RESTRICTED_INTERNAL`) rather than blocking exploratory collection or research with hard runtime permission gates.
- Carry `license_class` and `raw_hash` on ingested artifacts so production/redistribution views can filter via `PodView.allowed_licenses` cleanly.

### Polyglot Language Hierarchy

Everything runs reproducibly through the Nix flake (`nix develop -c <cmd>`); new dependencies belong in `flake.nix`.

- **OCaml 5 (`recorder/`, `fabric/ocaml/`, `wiki/server/`) — Default Systems Language:** Default for collectors, CLI tools, storage/CAS utilities (`mmfabric`), the markdown wiki/docs server (`mmwiki`), and systems infrastructure (`ocamlformat` janestreet profile, `ppx_js_style`, `-warn-error +a`).
- **Lean 4 (`fabric/lean/`, `subprojects/confirmation-wall/{kernel2,reference}/`) — Critical Proofs Without Rabbit Holes:** Prove high-leverage causal and accounting invariants directly in clean, fast, `warningAsError`-enforced Lean without adversarial compiler theater.
- **Python 3.13 (`fabric/`, `pods/`, `ingest/`, `ops/`) — ML, Stats, Data Analytics & MCP:** Use Python where its ecosystem excels (`numpy`, `scipy`, `polars`, `duckdb`, `pyarrow`, `xarray`, `tantivy`, `mcp`, Pydantic, Strategy Pods). Non-frozen Python passes `mypy --strict`, `ruff format --check`, and `ruff check`. Frozen recorder dependencies (`ingest/datalayer.py`, `ingest/live.py`, `ingest/sources_record.py`) remain lean stdlib modules for minimal live container images (`pythonFor`).
- **Nix (`flake.nix`, `ops/`):** Reproducible dev shells, container builds, homelab cluster deployments (`CLUSTER.md`), and verification checks (`nix run .#test`).

### Audit Record & Git Hygiene

- `audit/` (`decisions.md`, `criteria.md`, campaign logs, spent holdouts) and SQLite forecast ledgers are strictly append-only.
- Every timestamp added to `PROGRESS.md` or `audit/` (outside `audit/reviews/`) pairs `HH:MM UTC` with `HH:MM EST` or `EDT` on the same line (`ops/check-times.sh`).
- Keep `PROGRESS.md` concise (`<= 12,288` bytes). Never modify `data/` artifacts or `~/embargo/` holdouts in code commits, and verify `nix run .#test` passes before handoff.
