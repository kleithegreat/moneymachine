# Neon's efficiency audit of the recorders (`main`, `recorder/`)

Model `gemini-4-neon-xhigh` through agy, in a clean detached worktree of `main` (no `data/`, no tokens). Prompt below; two parts, verbatim. Advisor's checks against the code, 2026-11-18:
- **Finding 2 confirmed:** `mmvault` decodes and parses every file it has ever stored, on every hourly run (`vault.ml:93-103`, `:243-244`). The same code catches every exception (`with _ -> ()`, `exception _ -> ()`), against `CLAUDE.md` §2. A corrupt file reads as empty, so the fills it holds are stored again; none are lost.
- **Finding 5, item 1, confirmed, a liveness defect:** `watch_listings` calls `Net.post` with no timeout (`run.ml:176-196`, `net.ml:210`). A stalled REST response stops listing discovery until the recorder restarts; the websocket recording continues.
- **Finding 5, the leaked socket, confirmed (minor):** when `connect_tls` fails its host check, the TCP socket is never closed (`net.ml:83-86`).
- **Finding 5, the shared TLS error, refuted:** it is deliberate (`net.ml:42-45`, `RECORDER.md` item 14). Only a failure before the ClientHello is written fills it, which is a local, permanent failure.
- **Finding 1** (layout) goes to the architect's round 8 with the replay's size.
- **Gains are estimates:** Neon's own figures.

## Prompt

# Efficiency and simplicity audit: the live recorders (branch main, `recorder/`)

You are auditing `recorder/` in this repository: `mmrec`, which records every Hyperliquid websocket channel for about 350 perps around the clock (about 1.6 to 2 GB of zstd a day), and `mmvault`, which pulls a vault's fills and funding. Read `CLAUDE.md` for the project's rules, and `recorder/RECORDER.md` and `recorder/VAULT.md`, the specifications. They run unattended on one small homelab node with a 300 GiB volume; a lost recording can never be refetched. Downstream, study 2's monthly replays will read these files (`audit/program/` describes them if present).

**Find "coal": code that is provably equivalent to something much more efficient or much simpler, as it stands.**
1. **Asymptotic waste:** quadratic work, repeated scans or re-parsing, buffers that grow with a file or an hour, recomputation a cache would avoid.
2. **Bespoke code where a well-known, studied algorithm, library or format fits:** name it, and say why it is safer.
3. **Large constant factors on the hot path:** per-frame allocation, JSON parsed where only a field is read, compression settings.
4. **The file layout itself, as it serves its readers:** each hour's file mixes every coin, so a reader wanting 17 coins decompresses all of them. Is there a layout or an index (seekable zstd, per-coin files, a side index of offsets) that keeps the specification's guarantees — every frame written as received, crash loss bounded to the unflushed second, append-only — while letting a reader skip what it does not need?

**For each finding:**
- file and lines, what the code does now, and its cost on the real volumes above;
- the replacement;
- **why it is equivalent**: what the files contain must not change unless the finding is about the layout, and then say exactly what a reader can still verify against the original bytes;
- **the risk to a live recording:** the recorder must not lose data while it is changed, so say how the change is deployed safely.

Rank by real impact. Skip micro-optimisations and style. Answer in parts under 1,500 words each; end part 1 with "PART 1 END" if you need more than one.

## Part 1

# Live Recorders (`recorder/`) Efficiency & Simplicity Audit — Part 1

**Volume baseline** (from [RECORDER.md](recorder/RECORDER.md#L156-L157), [PROGRESS.md](PROGRESS.md#L39), [kernel-v2.md](audit/program/kernel-v2.md#L385), [live.py](ops/live.py#L117-L134)):
- **`mmrec` (`ws` StatefulSet, 250m CPU / 512 MiB req / 1 GiB limit, unmirrored 300 GiB PVC):** ~350 perps (~880 subs on 8 conns), ~2.0 GB/day compressed (~70% `l2Book-fast`), 17.4× ratio on quiet hour 04 (1.27 GB → 73 MB) ⇒ **~34 GB/day uncompressed** (busy days up to 3× ≈ 100 GB/day), **~1.5–1.75 TB compressed / ~25–30 TB uncompressed** over 2 years. Study 2 reads only `l2Book-fast` + `trades` for **17 coins** (~1.95B quotes ≈ ~0.95 TB uncompressed / ~55 GB compressed, ~5–8% of read-channel bytes).
- **`mmvault` (`vault` CronJob `:07`, 100m CPU / 256 MiB req / 512 MiB limit):** 17,520 hourly runs over 2 years; ~27 fills/day baseline (~822 fills per 30-day daily re-read; alarm at 5,000 fills).

---

## 1. File Layout: Mixed-Coin Hourly Streams Force 15–20× Decompression & I/O Waste Across Study 2 Replays

- **Where:** [hour_path.ml](recorder/src/hour_path.ml#L12-L21), [writer.ml](recorder/src/writer.ml#L38-L78), [route.ml](recorder/src/route.ml#L3-L33), [RECORDER.md](recorder/RECORDER.md#L69-L110).
- **Current code & real-volume cost:**
  - Each hour's `l2Book-fast` (~1.4 GB/day compressed, ~24 GB/day uncompressed) and `trades` file interleaves all ~350 perps in one continuous zstd stream.
  - Even after skipping unused channels (`l2Book`, `allDexsAssetCtxs`, `events`), a single Month-24 Study 2 replay must stream **~1.1–1.2 TB compressed** and decompress/filter **~19–21 TB of JSONL** just to keep ~5–8% of it (15–30 h on one core before Lean processes an event, threatening B5's 24 h wall). Across 24 monthly × 2-host replays ($\sum_{m=1}^{24} \frac{2m}{24} = 25\times$), linear re-reading streams **~28–30 TB** off `prodesk7`'s single disk and decompresses **~475–520 TB**.
  - **Why naive layouts fail:**
    1. *Byte-offset side index into the continuous zstd stream:* cannot skip decompression (every block depends on the prior 4 MiB sliding window).
    2. *Time-chunked Seekable Zstd on the mixed stream:* the 17 active large-cap coins appear every second, so **0% of frames are skipped**, and 1 s independent frames double disk usage (measured 161 vs 73 MB/hr in [RECORDER.md](recorder/RECORDER.md#L103-L104)).
    3. *Hourly per-coin files for all channels:* ~880 files/hr × 17,520 hr = **15.4M files/2y** (~79% of a 300 GiB ext4's ~19.6M inodes, tripping [CLUSTER.md](CLUSTER.md#L160)'s ≤20% free-inode `diskguard` alarm) plus ~880 level-9 `ZSTD_CCtx`s (~16 GiB RAM).
    4. *Hash bucketing (e.g., 32 buckets):* coupon collector puts 17 coins into ~13.3/32 = **42%** of buckets (only ~2.4× reduction).

- **Replacement (two viable designs; 1A recommended):**
  - **1A — Recommended: Unchanged Live Append-Only Log + Closed-Hour Coin-Grouped Seekable Zstd (LSM WAL-to-Segment Pattern).**
    - Keep `mmrec`'s live writer completely unchanged (1s crash bound, 6 FDs, append-only).
    - Once an hour file is closed (stream ended, next hour open), a deterministic packer demuxes lines by `"coin"` (verbatim, preserving within-coin receive order; lines lacking `"coin"` go to `_other`) and writes one standard **Zstd Seekable Format** file (RFC 8878 skippable frame `0x184D2A5E` at EOF + coin table `coin → (frame_idx, comp_off, comp_len, raw_len, line_count)`), with **one continuous zstd frame per coin** (zero per-second flushes; ~2.5 MB/coin/hr uncompressed on `l2Book-fast`).
    - *Real gain:* Readers wanting 17 coins read the ~8 KB EOF table and seek straight to 17 frames (**15–20× less I/O, decompression, and parsing**: ~1.5–2.2 TB streamed / ~25–35 TB decompressed across all 24×2 replays). Because each coin's consecutive books sit 500 B apart (repeat-offset hits) with no per-second flush headers, compressed size drops **~25–45%** (extending the 300 GiB PVC if retired after verification). Still 1 file/channel/hour (zero inode growth), and standard `zstd -dc` / `mmrec cat` still decode the whole file transparently.
  - **1B — Pure Append-Only Alternative (Zero Compaction): Live Daily Per-Coin Files for `l2Book-fast` (and optionally `l2Book`).**
    - Route `l2Book-fast` (70% of bytes) by `"coin"` directly in `mmrec` to `<root>/l2Book-fast/<YYYYMMDD>/<coin>.<run>.jsonl.zst` (daily rotation = ~256k files/2y, 1.3% of inodes; keep sparse `trades` mixed).
    - Set `ZSTD_c_windowLog=15` (32 KiB = ~36 s of one coin's books), `hashLog=13`, `strategy=dfast` (~250 KiB/`ZSTD_CCtx` ⇒ **~88 MiB** for 350 coins, less C heap than today's 6 × ~18 MiB level-9 contexts!).
    - *Tradeoff vs 1A:* Keeps strict append-only with zero offline compaction, but adds ~350 open FDs to the live recorder and pays ~10–15 B zstd block-header overhead per 500–1,000 B flushed coin-second (20–40% of a ~40 B compressed payload), partially offsetting same-coin locality — net size (~0.85–1.25×) must be measured on one recorded hour before adopting on the 300 GiB PVC. Also, during `[2026-11-01, 2027-01-31)`, `mmrec check` must aggregate to `(hour, channel)` so per-coin sizes are not exposed pre-release.

- **Why it is equivalent & what a reader can still verify against original bytes:**
  - Every recorded line (`{"recv":...,"conn":...,"msg":...}`) is preserved **byte-for-byte** with exact within-coin receive order and exact multiplicity. Cross-coin line interleaving never enters Kernel v2 ([kernel-v2.md](audit/program/kernel-v2.md#L46) A3 orders by `(time, class, coin, kind, position)` — `coin` precedes source position).
  - For **1A**, if full cryptographic verifiability against the original mixed file's SHA-256 is required, append one extra zstd frame holding the per-line 16-bit coin-index sequence (~2 B/line uncompressed ≈ 1–2 MB/hr compressed): readers wanting 17 coins skip it, while any auditor can interleave all coin frames back into the **exact original mixed `.jsonl` byte-for-byte** and check its SHA-256. Under Study 2's two-host model, two distinct hosts run the frozen packer on each closed hour and require byte-identical output.

- **Live-recording risk & safe deployment:**
  - **1A:** **Zero risk to `mmrec`** — `ws` is neither modified nor restarted. Run the packer out-of-process on closed hours (e.g., on the mirror/replay host so raw files on `ws` stay strictly untouched; only retire raw closed hours on `ws` if `RECORDER.md` L108 is explicitly amended and only *after* confirming closed stream + two-host byte-identical packed hash + `fsync`).
  - **1B:** Upgrade `mmrec check`/`cat` first to read both layouts; benchmark 1-hour compressed size and verify container `RLIMIT_NOFILE ≥ 4096`; soak-test 2 hours on a separate IP; pre-pull image on `prodesk7` and roll out `ws` in a quiet minute (~15–25 s reconnect gap, append-only rollback by digest).

---

## 2. `mmvault`: $O(T^2)$ Full-History Rescan Every Hour, Wasted `Funding` Scan, and Non-Streaming `decoded`

- **Where:** [vault.ml](recorder/src/vault.ml#L84-L103) (`decoded`, `stored_identities`), [vault.ml](recorder/src/vault.ml#L243-L244) (`run`), [zstd_stubs.c](recorder/src/zstd_stubs.c#L71).
- **Current code & real-volume cost:**
  1. **Unconditional $O(T^2)$ rescan:** `mmvault` appends a new `fills` file every hour (even for empty/duplicate pages, [VAULT.md](recorder/VAULT.md#L59)) plus daily 30-day re-reads of `fills` (~822 fills ≈ ~280 KB uncompressed) and `funding` (~160 rows). By month 24 that is **~18,250 files** (~250 MB uncompressed). Because every hourly run rescans every file since 2026-11-01, 17,520 runs perform **~1.6 × 10⁸ file opens** and decompress + full-AST `Yojson`-parse **~2.1 TB** of JSON (scaling to **~13 TB** and ~1.5 GB/hour near the 5,000-fill/30d alarm ceiling on a `100m` CPU CronJob!).
  2. **Wasted `Funding` scan on 23/24 runs:** [vault.ml](recorder/src/vault.ml#L244) calls `stored_identities config Funding` unconditionally at startup, even though `funding_seen` is only used inside `reread ()` when `hourly.complete && due` (once per UTC day).
  3. **Duplicate non-streaming decoder & hidden C-heap bloat:** `decoded` ([vault.ml](recorder/src/vault.ml#L84-L90)) duplicates [recording.ml](recorder/src/recording.ml#L5-L35) by calling `In_channel.read_all`, copying the entire decompressed file into `Buffer.t`, copying again via `Buffer.contents`, and a third time via `String.split_lines`. Each file also allocates a fresh `ZSTD_DCtx` whose internal ~4.25 MiB ring buffer (allocated on every >128 KiB daily file because `mmvault` writes level-9 `windowLog=22` streams without pledged size) is reported as `0` bytes to OCaml GC ([zstd_stubs.c](recorder/src/zstd_stubs.c#L71)) — risking RSS spikes against `vault`'s **512 MiB** container limit ([live.py](ops/live.py#L131)).

- **Replacement:**
  1. **Lazy `funding_seen`:** move `stored_identities config Funding` inside `reread ()` (eliminates 96% of funding scans).
  2. **Erase `decoded`:** stream lines through `Recording.fold_lines` (or Finding 3's zero-copy slice iterator) reusing **one resettable `ZSTD_DCtx`**, extracting only `"tid"` / `("delta"."coin", "time")` without building full `Yojson` ASTs for prices/sizes/fees.
  3. **Validated rebuildable identity cache:** store `<root>/vault/<user>/.identities.<kind>.cache` (written via `.tmp` + atomic `rename`) recording `(rel_path, size, mtime_ns)` of already-indexed files plus their identity set. On startup, `stat` the files under `<kind>/`: if every cached file still exists with matching `(size, mtime_ns)`, scan **only new files** (1 file/hour instead of 18,250 → $O(1)$ per run, $O(T)$ cumulative!); if missing, corrupt, or any cached file changed/vanished, transparently rebuild from all stored files. (Update [VAULT.md](recorder/VAULT.md#L42) to document the validated cache while keeping `state.json` untouched.)

- **Why it is equivalent:** For append-only immutable files, the validated cache produces the **exact same** `Hash_set` as a full rescan on every run, including after `SIGKILL` at any instruction (an unupdated cache simply scans the 1 new file left by the killed run; a torn `.tmp` is ignored). Stored `.jsonl.zst` files, `state.json`, and emitted events are **byte-for-byte identical**.

- **Live-recording risk & safe deployment:** Minimal — `vault` is an hourly CronJob (`:07`, `Forbid`) that never touches `ws`. Dry-run against a copied snapshot of `data/ws/vault/` verifying identical `seen` sets and event lines; deploy image digest between `:15` and `:55`; rollback by reverting the CronJob digest and deleting `.identities.*.cache` if needed (1 h overlap + 30 d daily re-read guarantees zero lost fills even if a single hourly run were skipped).

*(Part 2 covers Findings 3–5: Zstd C-stub memory/allocation & `mmrec cat`/`check` 4× line copies, `mmrec run` hot-path `Yojson`/string-copy/flush churn, bespoke HTTP/WS in `net.ml`, and the ranked summary.)*

PART 1 END

## Part 2

# Live Recorders (`recorder/`) Efficiency & Simplicity Audit — Part 2

## 3. Zstd C-Stub Allocation, Unaccounted C Heap, and 4× Line Copies in `mmrec cat`/`check`

- **Where:** [zstd_stubs.c](recorder/src/zstd_stubs.c#L27-L98), [zstd.ml](recorder/src/zstd.ml#L11-L38), [recording.ml](recorder/src/recording.ml#L5-L35), [mmrec.ml](recorder/bin/mmrec.ml#L44-L56), [integrity.ml](recorder/src/integrity.ml#L93-L115), [line.ml](recorder/src/line.ml#L13-L36), [writer.ml](recorder/src/writer.ml#L38-L63).
- **Current code & real-volume cost:**
  1. **Per-step `malloc` + major-heap copy:** `mmrec_zstd_decompress_step` ([zstd_stubs.c](recorder/src/zstd_stubs.c#L81-L92)) calls `malloc(ZSTD_DStreamOutSize())` (128 KiB), decompresses into it, copies into a fresh 128 KiB OCaml major-heap string via `caml_alloc_initialized_string`, and `free`s it — **~260k `malloc`/`free` + major-heap allocations per recorded day** (~7.8M/month on 34 GB/day uncompressed). `mmrec_zstd_compress_step` ([zstd_stubs.c](recorder/src/zstd_stubs.c#L45-L57)) repeats the same pattern (~128.5 KiB `malloc`/`free` per step), followed by [zstd.ml](recorder/src/zstd.ml#L12-L19) allocating a `Buffer` (`input/4 + 64`) and copying twice more. [zstd.ml](recorder/src/zstd.ml#L30) also hardcodes `cap = 131072` instead of querying `ZSTD_DStreamOutSize()`.
  2. **4× full-stream copies in `Recording.fold_lines`:** Every decompressed line crosses four buffers: `ZSTD_decompressStream` → `malloc` `buf` → OCaml `chunk` string → `partial` `Buffer.t` ([recording.ml](recorder/src/recording.ml#L16), unconditionally copied even though `partial` is empty on ~99.5% of lines) → `Buffer.contents` `line` string ([recording.ml](recorder/src/recording.ml#L17)), plus `Bytes.To_string.sub` copying every 64 KiB compressed read ([recording.ml](recorder/src/recording.ml#L29)).
     - `mmrec cat` ([mmrec.ml](recorder/bin/mmrec.ml#L50-L52)) allocates ~50–65M line strings/day only to write raw lines + `'\n'` to `stdout`.
     - `mmrec check` ([integrity.ml](recorder/src/integrity.ml#L97-L105)) allocates all ~136 GB of copies/day (~4 TB per monthly check) only to inspect the first ~30 bytes in `Line.envelope` — which itself allocates two more `String.sub` strings per line ([line.ml](recorder/src/line.ml#L19)).
  3. **Unaccounted C heap & per-file context churn:** Both `caml_alloc_custom` calls ([zstd_stubs.c](recorder/src/zstd_stubs.c#L35), [zstd_stubs.c](recorder/src/zstd_stubs.c#L71)) report `used = 0` bytes to OCaml's GC. `writer.ml` allocates fresh level-9 `ZSTD_CCtx`s (~18–24 MiB each × 6 routes ≈ 110–145 MiB) every UTC hour ([writer.ml](recorder/src/writer.ml#L42)) without freeing or resetting the old ones; `recording.ml` allocates a fresh `ZSTD_DCtx` (~4.25 MiB ring buffer for `windowLog=22`) per file ([recording.ml](recorder/src/recording.ml#L7)), risking RSS spikes against [RECORDER.md](recorder/RECORDER.md#L201)'s 128 MiB `check`/`cat` bound and `vault`/`ws` container limits.
- **Replacement:**
  1. **Caller-owned reusable buffers in `zstd_stubs.c`:** Pass pre-allocated `Bytes.t` (or pinned `Core.Bigstring.t` if releasing the OCaml runtime lock) `src`/`dst` slices directly into `ZSTD_compressStream2` / `ZSTD_decompressStream`, returning `(src_pos, dst_written, hint_or_rem)`. Expose `ZSTD_CStreamOutSize()` / `ZSTD_DStreamOutSize()` to OCaml. Zero `malloc`/`free`, zero `caml_alloc_initialized_string`, zero extra `Buffer` in `Zstd.compress`.
  2. **Context reuse & GC accounting:** Register C-heap estimates with `caml_alloc_custom_mem` using `ZSTD_estimateCStreamSize(level)` / `ZSTD_estimateDStreamSize(1 << 22)` (since `ZSTD_sizeof_*` is small before the first step), and expose `ZSTD_CCtx_reset(cctx, ZSTD_reset_session_only)` / `ZSTD_DCtx_reset` so each `writer.ml` route reuses one `ZSTD_CCtx` across hours and `mmrec check` / `mmvault` reuse one `ZSTD_DCtx` across all files.
  3. **Zero-copy slice & whole-chunk streaming:** Replace `Recording.fold_lines` with `Recording.iter_lines ~dctx path ~f:(fun buf ~pos ~len -> ...)` that invokes `f` directly on the decompressed `out_buf` slice whenever `partial` is empty (~99.5% of lines), and parse `recv`/`conn` in `Line.envelope_bytes` via an integer digit loop (0 allocations). For `mmrec cat`, add a chunk pass that locates the last `'\n'` in `out_buf` (`Bytes.rindex_from`), writes `partial` + `out_buf[0..last_nl]` in one `Out_channel.output`, and retains only the short trailing fragment (discarded on truncation).
- **Why it is equivalent:** `ZSTD_CCtx_reset(..., ZSTD_reset_session_only)` keeps level 9 and `checksumFlag = 1` while starting a clean stream identical to a fresh `ZSTD_CCtx`. `mmrec cat`, `mmrec check`, and `mmrec run` produce **byte-for-byte identical** output, including partial-line dropping on truncated files.
- **Live-recording risk & safe deployment:** **None** for `mmrec cat`/`check` and `mmvault` (offline/CronJob). For `ws`, changes touch `zstd_stubs.c`/`writer.ml`: verify `mmrec-tests` (including kill/cut tests and 1 GiB <128 MiB RSS test), soak 2 hours on a separate IP, pre-pull image on `prodesk7`, and roll out `ws` in a quiet minute (~15–25 s reconnect gap; append-only rollback by image digest).

---

## 4. `mmrec run` Hot Path: Per-Frame Full-AST `Yojson` Parsing, 5× String Copies, and Synchronous Level-9 Flushes

- **Where:** [route.ml](recorder/src/route.ml#L13-L23), [line.ml](recorder/src/line.ml#L3-L7), [run.ml](recorder/src/run.ml#L102-L113), [writer.ml](recorder/src/writer.ml#L45-L78), [zstd_stubs.c](recorder/src/zstd_stubs.c#L33).
- **Current code & real-volume cost:**
  1. **Full JSON AST built and discarded on every frame:** Despite [RECORDER.md](recorder/RECORDER.md#L143) ("reads only `channel`"), `Route.of_frame` ([route.ml](recorder/src/route.ml#L14)) calls `Yojson.Safe.from_string frame` on **every incoming frame** (~50–65M frames/day, 34 GB/day baseline, up to 100 GB/day busy), building full OCaml ASTs for every order-book price/size level and every `allDexsAssetCtxs` field (~5–8× raw size ≈ **170–270 GB/day**, up to **500–800 GB/day** of throwaway heap garbage) just to look up `"channel"`.
  2. **5× per-frame copy chain:** `Line.sanitize` ([line.ml](recorder/src/line.ml#L3)) runs `String.map` unconditionally (copy #1, though >99.99% of frames contain no CR/LF); `Line.of_frame` ([line.ml](recorder/src/line.ml#L6)) formats with `sprintf` (copy #2) and appends `^ "\n"` (copy #3!); `Writer.add` copies into `Buffer.t` (copy #4, [writer.ml](recorder/src/writer.ml#L76)); `Writer.flush` copies up to 1 MiB out via `Buffer.contents` (copy #5, [writer.ml](recorder/src/writer.ml#L57)). That is **~170–500 GB/day** of memory copies and ~150–200M short-lived allocations/day.
  3. **Synchronous level-9 compression on a single Async thread:** `ZSTD_compressStream2` at level 9 (`btlazy2`, ~25–45 MB/s/core) runs synchronously inside Async on a `250m`-CPU-requested pod ([live.py](ops/live.py#L122)); a 1 MiB busy-second flush blocks all 8 WebSocket readers for ~20–40 ms, delaying `recv_ms = now_ms ()` ([run.ml](recorder/src/run.ml#L103)) during volatility bursts.
- **Replacement:**
  1. **Zero-allocation top-level `"channel"` scanner + RFC 8259 validator in `Route.of_frame`:** A single ~60-line byte scan tracks nesting depth and string escapes with zero heap allocations, captures the first top-level `"channel"` value (falling back to `Yojson.Safe.from_string` only if a `\` escape occurs in that key/value — 0% of live frames), validates the remainder so malformed JSON still routes to `Events` ([route.mli](recorder/src/route.mli#L14)), and returns `needs_sanitize : bool` (whether `\r`/`\n` appeared).
  2. **Direct-to-staging-buffer framing (`Writer.add_frame`):** Replace `Buffer.t` in `writer.ml` with a reusable growable `Bytes.t` staging buffer passed straight into Finding 3's zero-copy `Zstd.compress_into` (eliminating `Buffer.contents`). Write `{"recv":<int>,"conn":<int>,"msg":`, then one `Bytes.blit_string` of `frame` (or inline CR/LF→space copy only when `needs_sanitize`), then `}\n`. Reduces hot-path allocations to **0 per frame** and copies from **5× to 1×**. (Keep `Line.of_frame` as a thin wrapper over the same writer for tests.)
  3. **Optional compression-level tuning (spec amendment):** Benchmark levels 3, 5, 6 vs 9 on one real hour before changing [RECORDER.md](recorder/RECORDER.md#L101). Level 5–6 cuts compression CPU and flush-stall latency **~3–5×** (and `ZSTD_CCtx` RAM ~2–4×) at ~2–6% disk cost — and if paired with Finding 1A's closed-hour packer, live level 3–5 + offline high-level coin compaction wins on both CPU and disk.
- **Why it is equivalent:** Parts (1)+(2) produce **bit-for-bit identical** `.jsonl` lines and `.jsonl.zst` files; differential `base_quickcheck` tests over arbitrary, escaped, nested, duplicate-key, and malformed JSON prove `Route.of_frame` matches `Yojson.Safe.from_string` everywhere. Part (3), if adopted, still writes standard checksummed zstd streams decompressing **byte-for-byte identically** to the same lines.
- **Live-recording risk & safe deployment:** **Low–Medium** (touches the live frame-routing and framing path of `ws`). Gate behind differential QuickCheck + full `mmrec-tests` + 2-hour soak on a separate IP comparing channel/line integrity against the live feed; pre-pull image and roll out `ws` in a quiet minute (~15–25 s reconnect gap; append-only rollback by digest).

---

## 5. Bespoke HTTP/1.1, WebSocket Upgrade, and TLS Pipe Plumbing in `net.ml`

- **Where:** [net.ml](recorder/src/net.ml#L17-L214), [dune](recorder/src/dune#L3), [run.ml](recorder/src/run.ml#L178), [flake.nix](flake.nix#L71).
- **Current code & real-volume cost:** [net.ml](recorder/src/net.ml) hand-rolls 214 lines of URL parsing, TLS pipe bridging, HTTP/1.1 POST + chunked decoding, and RFC 6455 WebSocket upgrade, introducing concrete reliability and liveness defects:
  1. **Unbounded hang in `watch_listings`:** `Net.post` ([net.ml](recorder/src/net.ml#L210-L214)) has **no timeout** (only `mmvault` wraps `post_status` in `Clock.with_timeout`), and `post_status` ignores `Content-Length`, calling `Reader.contents` until EOF ([net.ml](recorder/src/net.ml#L203)). A stalled connection or ignored `Connection: close` hangs `watch_listings` ([run.ml](recorder/src/run.ml#L178)) forever, silently halting hourly listing discovery.
  2. **Process-bricking global `tls_context` Ivar & FD leak:** If the very first TLS connect fails before writing ClientHello, `tls_context` ([net.ml](recorder/src/net.ml#L46-L82)) is permanently filled with `Error`, failing every future reconnect and REST call forever. If `connect_tls` raises (e.g., hostname mismatch, [net.ml](recorder/src/net.ml#L83)), the underlying TCP socket ([net.ml](recorder/src/net.ml#L99)) is never closed. Every TLS connection also routes all 34–100 GB/day through 3 extra Async `Pipe` bridges + `Reader`/`Writer.of_pipe` ([net.ml](recorder/src/net.ml#L52-L87)).
  3. **Non-compliant HTTP/1.1 & RFC 6455:** `handshake_key` ([net.ml](recorder/src/net.ml#L125-L128)) uses non-cryptographic `Random.int` and pulls in `cryptokit` solely for `Base64.encode_compact ()`, which strips RFC 6455 §4.1's required `=` padding; `upgrade` ([net.ml](recorder/src/net.ml#L140-L146)) ignores `Upgrade`, `Connection`, and `Sec-WebSocket-Accept`; `post_status` checks case-sensitive `Some "chunked"` ([net.ml](recorder/src/net.ml#L202)), omits non-default ports from `Host:`, and allocates unbounded `Bytes.create size` in `read_chunks` ([net.ml](recorder/src/net.ml#L173)).
- **Replacement:** Replace bespoke HTTP/URL/upgrade code with standard Async libraries from the pinned `nixpkgs` ([RECORDER.md](recorder/RECORDER.md#L138), keeping `flake.lock` and Stage 3's `harness_hash` untouched): **`uri`** + **`cohttp-async`** (`Cohttp_async.Client.post` with `~interrupt:(Clock_ns.after (sec 30.))` for REST) and Jane Street's **`cohttp_async_websocket`** (`Cohttp_async_websocket.Client.create` for RFC 6455 upgrade + `Conduit_async` TLS; if `cohttp_async_websocket` is absent from the pinned nixpkgs snapshot, pair `cohttp-async` + `uri` + `base64` with a 25-line RFC-6455-validating upgrade checking `Upgrade`, `Connection`, padded 24-char key, and `Sec-WebSocket-Accept`). Drop the `cryptokit` dependency from [dune](recorder/src/dune#L3), wrap TCP setup in `Monitor.protect` to eliminate FD leaks, and replace the sticky `tls_context` Ivar with an explicit CA-file preflight + per-attempt `Async_ssl` error propagation (preserving [RECORDER.md](recorder/RECORDER.md#L206-L207) item 14 without poisoning retries).
- **Why it is equivalent:** Wire-level JSON frames, routing, events, and stored `.jsonl.zst` files are **byte-for-byte identical** on all valid responses; invalid HTTP/WS upgrades and stalled REST calls now fail closed into `error` events and retry cleanly instead of silently hanging or leaking sockets.
- **Live-recording risk & safe deployment:** **Medium** — alters live transport/TLS/reconnect code for both `ws` and `mmvault`. Validate against all fake-server TLS, non-101, mid-frame reset, and timeout tests (items 7, 14, 15 in [RECORDER.md](recorder/RECORDER.md#L184-L211)), soak several hours against live Hyperliquid on a separate IP (forcing a reconnect + hourly listing refresh), deploy to `vault` first (safe CronJob canary), then roll out `ws` in a quiet minute (~15–25 s reconnect gap; instant digest rollback).

---

## Ranked Summary of All Five Findings

| Rank | Finding | Real Gain (Production / 2-Year Volumes) | Live-Recording Risk & Rollout |
|---:|---|---|---|
| **1** | **Mixed-coin hourly layout** ([hour_path.ml](recorder/src/hour_path.ml), [writer.ml](recorder/src/writer.ml)) | **15–20×** less replay I/O & decompression (~28–30 TB → ~1.5–2.2 TB streamed; ~475–520 TB → ~25–35 TB decompressed across 24×2 Study 2 replays); **25–45% smaller** closed hours under 1A. | **None (1A):** `ws` untouched; offline packer on closed hours.<br>**Medium (1B):** ~350 live FDs, 15–25 s gap, size benchmark required. |
| **2** | **`mmvault` $O(T^2)$ rescan, wasted `Funding` scan & `decoded`** ([vault.ml](recorder/src/vault.ml)) | **$O(T^2) \to O(T)$:** ~1.6×10⁸ opens & ~2.1–13 TB JSON parses → ~18k opens & ~250 MB (~10,000× less work at month 24); 96% fewer `Funding` scans; removes 3× copies & `ZSTD_DCtx` RSS spikes. | **Minimal:** hourly `:07` CronJob (`Forbid`), never touches `ws`; 1 h overlap + 30 d re-read absorbs any skipped run. |
| **3** | **Zstd C-stub `malloc`/copies, uncounted C heap & `cat`/`check` 4× copies** ([zstd_stubs.c](recorder/src/zstd_stubs.c), [recording.ml](recorder/src/recording.ml)) | Removes ~260k/day 128 KiB `malloc`/major-heap allocs & **4× → 1×** copies (~136 GB/day, ~4 TB/month saved in `cat`/`check`); reuses resettable contexts with `caml_alloc_custom_mem` (eliminates ~110–145 MiB/hr lingering C heap in `ws`). | **None** for `cat`/`check`/`vault`; **Low** for `ws` (2 h soak + 15–25 s StatefulSet rollout; append-only digest rollback). |
| **4** | **`mmrec run` hot-path `Yojson` AST, 5× frame copies & sync level-9** ([route.ml](recorder/src/route.ml), [line.ml](recorder/src/line.ml)) | Eliminates **~170–800 GB/day** of throwaway `Yojson` AST garbage and **5× → 1×** frame copies (~170–500 GB/day) on `250m` CPU; optional level 9→5/6 cuts sync flush stalls & compression CPU **~3–5×**. | **Low–Medium:** hot-path routing/framing change on `ws`; gate with differential QuickCheck + 2 h separate-IP soak + 15–25 s rollout. |
| **5** | **Bespoke HTTP/1.1, WS upgrade & TLS plumbing** ([net.ml](recorder/src/net.ml)) | Deletes ~200 lines of hand-rolled protocol code & `cryptokit`; fixes unbounded `Net.post` hang in `watch_listings`, sticky `tls_context` bricking, TLS FD leaks, unpadded WS key & missing `Sec-WebSocket-Accept` check. | **Medium:** live transport/TLS change; deploy to `vault` canary first, multi-hour live soak on separate IP, then `ws` rollout (~15–25 s gap). |
