# GPT sandbox: the `execute` and `task` gap, and which past runs it could have touched (2026-10-26)

**The gap.** opencode 2.0.32 has a Code Mode tool, `execute`, that runs JavaScript. That JavaScript calls `fetch()`
directly, so it reaches the web without the `webfetch` permission. Sub-agents are another tool, recorded in the
session store as `subagent`; the deprecated permission object's key for them is `task`. Our independence configs
denied `edit`, `bash`, `webfetch` and `external_directory`, but none of these. From 2026-10-26 they deny all three
names:

```json
{"permission": {"edit": "deny", "bash": "deny", "webfetch": "deny", "external_directory": "deny", "execute": "deny", "task": "deny", "subagent": "deny"}}
```

**Which past runs used what** (`session-tool-audit.txt`: every opencode session whose directory is a moneymachine GPT
directory, from opencode's own session store, read-only; per session, each tool's calls by status, and every call
to a web, shell, code, sub-agent or skill tool, or with a path outside the session's directory):

- **`execute`:** only the stage 8 source survey (`~/.cache/mm-gpt/stage8-sources.*`, 2026-10-26), whose config allowed
  `webfetch` and `websearch` on purpose (a documentation survey, not an independence run). It fetched vendor terms and
  documentation pages. It also used sub-agents and the `deep-research` skill; its reads of the skill's files outside
  its directory failed.
- **`bash`:** only the stage 4 swarm and canonicalization review of 2026-10-19 (`gpt-c4`, before `bash` was denied):
  three one-line Python computations of floating-point behavior, touching no file.
- **Reads outside the run's directory that succeeded:** five runs whose directories were inside the repository
  (`data/tmp/`) and whose configs, written before 2026-10-24, did not deny `external_directory`. Each read the repo's
  `PROGRESS.md`, and nothing else outside its directory:

  | Run | Date (UTC) | Purpose | What it saw |
  |---|---|---|---|
  | `derived3` | 2026-10-22 21:08 | GPT's independent Python implementation of `derived.md`'s event counts (C5.5) | PROGRESS.md as of that day (52,038 characters): status and criteria summaries, no source code |
  | `stage7` | 2026-10-23 06:08 | review of stage 7's criteria | PROGRESS.md |
  | `gpt6c` | 2026-10-23 06:48 | third review of stage 6's exit evidence | PROGRESS.md (first 220 lines) |
  | `stage8` | 2026-10-23 07:09 | review of stage 8's criteria | PROGRESS.md |
  | `stage9` | 2026-10-23 15:25 | review of stage 9's criteria | PROGRESS.md |

- Every other run, including every other independent implementation (rule language, resolver, both fill checkers,
  null generators, DSR, scorer, laws) and both red-team rounds, used no tool or read only inside its own directory.

**Effect.** No independent implementation saw source code. One, `derived3`, saw the project's status document, whose
derivation conventions restate `derived.md`; its independence is weakened, not broken. The four reviews saw the
status document, which reviews may see. A clean reimplementation of the event counts from `derived.md` alone is
queued for when GPT is available.

**Not yet established:** a live probe of `execute` (reading a canary file outside the directory, and fetching a page)
under the configs used before and after the fix. GPT reached its ChatGPT usage limit before the probes ran; they are
queued (`~/.cache/mm-gpt/probe-*`, canary under `~/.cache/mm-gpt-canary/`).

## Live probes, 2026-10-26 21:47 UTC (17:47 EDT), after GPT's return

Each probe asked GPT, under one config, to read the canary `~/.cache/mm-gpt-canary/token.txt` (its value never in
the prompt) and to fetch https://example.com by any tool; replies and configs are `probe-*.txt` and
`probe-*.opencode.json` beside this file.

| Config | Read outside its directory | Web |
|---|---|---|
| current (`probe-exec-after`: edit, bash, webfetch, external_directory, execute, task, subagent denied) | denied (`external_directory`) | none: `execute` unavailable, web search cancelled |
| 2026-10-24 to 26 (`probe-exec-before`: execute, task, subagent not denied) | denied | **allowed** through `execute`'s `fetch()` (HTTP 200) |
| before 2026-10-24 (`probe-readext-old`: external_directory not denied) | **allowed**: the canary returned exactly | allowed through `execute` |

A second probe under the 2026-10-24 config (`probe-exec-before.txt`; the first reply is `probe-exec-before-1.txt`)
tried every JavaScript file API in `execute` (`Deno`, `Bun`, `require`, `import`, `fetch("file://")`): none exists
or works ("fetch cannot be used for filesystem access"). So `execute` reached the web but never the filesystem: the
runs of 2026-10-24 to 26 could have looked things up online, not read the repository. This confirms the effect above:
no independent implementation saw source code; `derived3` saw PROGRESS.md.

**Resolved 2026-10-26 22:03 UTC (18:03 EDT):** the clean reimplementation of the derived event counts agrees on every
case and replaces `derived3`'s module (`audit/stage5/c55-evidence.md`).
