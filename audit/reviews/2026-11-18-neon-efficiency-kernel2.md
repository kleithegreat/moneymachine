# Neon's efficiency audit of kernel v2 (`kernel2-step5` at 7308398)

Model `gemini-4-neon-xhigh` through agy, in a clean detached worktree of `kernel2-step5` (no `data/`, no tokens), asked for code provably equivalent to something much faster or simpler (prompt below). Two parts, verbatim. Advisor's spot checks against the code, 2026-11-18:
- **Finding 1 confirmed:** `Win.push` appends to a list, takes its length and filters it on every tick (`Eval.lean:55-92`).
- **Finding 3 confirmed:** `insertPending` is a linear insert into a list (`MachineCore.lean:476`).
- **Finding 6 confirmed:** `tickBody` computes `marks`, then `viewMarkAt` recomputes every coin's mark for each lookup (`MachineCore.lean:840,670`).
- **Finding 8 overstated:** B4 replayed in full on this code, so there is no "guaranteed" out-of-memory. The bulk path (`run_streams`) streams, and day files fit. `mm2 finish` holding a whole run's state and output in memory is real, and matters for long replays.
- **Gains are estimates:** Neon's hours figures are its own. They are to be measured before and after each fix.

## Prompt

# Efficiency and simplicity audit: kernel version 2 (branch kernel2-step5)

You are auditing this repository's kernel version 2: `kernel2/lean/Engine/` (Lean 4, compiled to C and called from OCaml) and `kernel2/ocaml/` (the `mm2` executable, its archive reader, tests). Read `CLAUDE.md` for the project's rules, and `kernel2/KERNEL.md` and `audit/program/kernel-v2.md` for what the engine must do. The engine replays a market's events (millions of quotes and prints a day) and evaluates trading programs on them; a replay of study 2 runs over months of data, and the archive window over 212 days.

**Find "coal": code that is provably equivalent to something much more efficient or much simpler, as it stands.** Specifically:
1. **Asymptotic waste:** quadratic or worse work that could be linear or n log n (repeated list appends, nested scans, re-sorting, re-reading or re-parsing the same data, recomputation a cache or an incremental update would avoid). One such defect was already found and fixed: `Machine.go`'s right-nested append copied a chunk's rows at every event; look for its siblings.
2. **Bespoke code where a well-known, studied algorithm or data structure fits:** name it (e.g. a monotone deque for window extremes, Welford/Kahan for running sums, a binary heap or a sorted map for a queue, a dynamic program for a brute-force search), and say why the standard one is safer.
3. **Large constant factors on the hot path:** arbitrary-precision `Rat`/`Nat` where the value range is bounded, `Nat.pow` or string parsing in an inner loop, allocation per event.

**For each finding:**
- file and lines, and what the code does now, with its cost (asymptotic, and an estimate on the real sizes above);
- the replacement;
- **why it is equivalent**: a proof sketch that outputs, order, and failure behaviour are identical, or exactly where equivalence is only testable (floating point, order of reductions) — the engine's outputs must stay bit-identical, and its Lean laws must still hold, so say whether a law's proof would need to change;
- the gain in hours or memory on a real replay.

Rank by real impact. Skip micro-optimisations and style. Do not propose changing any semantics the laws fix. Answer in parts under 1,500 words each; end part 1 with "PART 1 END" if you need more than one.

## Part 1

# Kernel Version 2 Efficiency & Simplicity Audit — Part 1

**Scale baseline (from `kernel-v2.md` B5):** 212-day archive replay = 16 coins, **229M quotes** (80 doubles each = 18.3B numbers; densest day 2.49M quotes ≈ 28.8/s) + prints; 2-year forward run = 17 coins, **1.95B quotes** (20 strings each = 39B numbers). Ticks: 305k (1-min, 212d), 1.05M (1-min, 2y), 18.3M (1-s, 212d). Budget: ≤8h (4h admission) on 1 core, ≤2 GB RAM.

---

## 1. Rolling Windows (`Win.push`) & `Mach.step` Reference-Count CoW Trap
- **Where:** [Eval.lean](kernel2/lean/Engine/Lang/Eval.lean#L26-L31), [Win.push](kernel2/lean/Engine/Lang/Eval.lean#L55-L92), [build / Mach.step](kernel2/lean/Engine/Lang/Eval.lean#L271-L279).
- **Current code & cost:**
  1. `Win.lag` (L56–59) and `Win.sums` (`sum`/`mean`/`std`, L60–80) store buffers as `List (Option α)` and run `buf ++ [x]` plus 2–3 `b.length` scans every tick ($\Theta(W)$ per coin per tick).
  2. `Win.sums` L71 computes `let defined := b.filterMap id` **unconditionally** before `if since ≥ n`, defeating its own $O(1)$-amortized periodic recomputation and allocating a length-$W$ list on every tick.
  3. `Win.extreme` (`min_over`/`max_over`, L81–92) implements a monotone deque on a `List` via `(dq.reverse.dropWhile dominated).reverse ++ [(seq, v)]` ($\Theta(|dq|)$, worst-case $\Theta(W)$ on trends).
  4. `List (Option UInt64)` uses ~56 B/entry (vs 9 B budgeted in `KERNEL.md` A17). At `maxWindowTicks = 1,048,576` across 17 coins, one window holds ~1.0 GB live plus ~1.5 GB transient during `++`/`filterMap` (**>2.5 GB, breaking the 2 GB wall**).
  5. **Lean 4 RC trap:** `build` (L271–276) recurses non-tail-recursively while holding `m` live across all `p.nodes.size` frames, pinning `m.ns` and every inner `Win` at `RC ≥ 2`. Even an `Array`-backed ring buffer would copy all $W$ elements on every tick unless `Mach.step` consumes `m.ns` linearly.
  - *Real-scale cost:* $\Theta(T \cdot C \cdot W)$. At 1-min ticks over 212d ($T = 305\text{k}, C = 16$), one 7-day `mean` ($W = 10{,}080$) copies ~$10^{11}$ cons cells (~25–35 min); one 30-day window ($W = 43{,}200$) takes **~2 h**. At 1-s ticks with a 1-day window ($W = 86{,}400$), $2.5 \times 10^{13}$ cells (**>100 h**).
- **Replacement:**
  - Replace `lag`/`sums` lists with a **circular ring buffer** (`Array (Option α)` growing lazily up to `cap`, with `head` and `len`); move `defined` inside `if since ≥ n`, folding directly over `(head + i) % cap` with zero intermediate list.
  - Replace `extreme`'s list with a **standard monotone deque** on a resizable circular array (or Okasaki two-list deque): $O(1)$ amortized front/back operations, $O(|dq|)$ memory, safer because no worst-case trend degenerates to $O(W)$.
  - Rewrite `Mach.step` as an iterative/tail-recursive loop that moves `m.ns[k]` out via `swap` (keeping `RC = 1`), enabling true in-place $O(1)$ ring updates.
- **Equivalence & laws:**
  - *Proof sketch:* Define `toList` on the ring/deque; index arithmetic modulo `cap` proves `toList (push' w x) = (toList w ++ [x]).drop ...`. For `sums`, `N.add`/`N.sub` execute identically; periodic recompute folds defined elements in the exact same left-to-right FIFO order from `N.neg N.zero` (zero float reordering). For `extreme`, back/front pops keep the identical `(seq, v)` sequence, preserving signed-zero ties. Total functions, identical failure behaviour.
  - *Law proofs:* Zero frozen law statements (`L2_units`, `L3_rewrite`, `N1_renaming`, `X1`, `C1`, `L1a`) inspect `Win`. `UnitsProofs`/`RewriteProofs`/`RenameProofs` treat `Win.push` as a black box; only `build_size`/`build_get` in [EvalProofs.lean](kernel2/lean/Engine/Lang/EvalProofs.lean#L22-L64) (~40 lines) adapt to linear `Mach.step` (or use `@[csimp]` on `Mach.step`).
- **Gain:** **Hours–days → seconds** ($\Theta(T \cdot C \cdot W) \to \Theta(T \cdot C)$); max-window RAM **~2.5 GB (OOM) → ~300 MB** (~160 MB with `FloatArray` + `ByteArray` for `UInt64`).

---

## 2. Transcendentals `exp` and `log` (X4): $O(M \cdot N^2)$ Big-Int `Rat` Recomputation
- **Where:** [Exact.lean](kernel2/lean/Engine/Exact.lean#L1494-L1572) (`factorial`, `expSum`, `expLoAt`/`expHiAt`, `logSplit`, `atanhSum`, `logLoAt`/`logHiAt`, `firstDeciding`, `exp`, `log`).
- **Current code & cost:**
  - `firstDeciding` (L1552–1556) tests every `n` from `first` to `last`, recomputing `lo n` and `hi n` from scratch at each `n` — and recomputing `lo n` a **third** time on `some n`.
  - `expSum` recomputes `a ^ k` and `factorial k` from scratch for every `k = 0..n` in `Rat` (GMP `gcd` at every addition/division), with no range reduction ($N \ge 2|x|$, so $N \ge 1{,}400$ at $x = 700$). Cost per call: $O(M \cdot N^2)$ bigint ops ($O(N^4)$–$O(N^5)$ bit ops).
  - `logLoAt`/`logHiAt` recompute `logSplit`, `atanhSum (1/3) n`, and `atanhSum z n` twice per `n`, calling `nearestBits` (recursive `natLog 2` on ~2,000-bit `Rat`s) on `n = 0..15` before the series can reach 53-bit precision.
  - *Real-scale cost:* ~0.5–5 ms per typical `log`/`exp` call (seconds at $|x| \approx 700$). One `log`-return node over 212d at 1-min ticks (4.88M calls) takes **~1–6 h**; at 1-s ticks (293M calls), **~40–400 h**; `x4_local`'s 2M draws take **hours–days**.
- **Replacement:**
  - Standard **Ziv's multilevel strategy / fixed-precision dyadic ball arithmetic** (CRlibm / CORE-MATH / Arb) as `@[csimp]` twins `expFast` / `logFast`:
    1. *Fast path (128-bit integer ball arithmetic, >99.999% of inputs):* For `log`, extract `(e, m)` from IEEE bits directly (zero `Rat`), bound `z = (m-1)/(m+1)` and 20 incremental `atanh` terms in 128-bit integers (floor for lower, ceil for upper) with precomputed 128-bit bounds for `atanhSum (1/3) 20 ± tail`, then apply Ziv's rounding test (`round64 L == round64 U`). For `exp`, run incremental `term_{k+1} = term_k * |x| / (k+1)` in 128-bit integer ball arithmetic at `n = expStart x + 30` (or add standard $x = k\ln 2 + r$ range reduction for large $|x|$), then Ziv's test.
    2. *Fallback (<$2^{-60}$ table-maker's dilemma cases):* Incremental rational `(s, term)` loop sharing `(s, t)` between `lo`/`hi` and using fast `nearestBits` (Finding 4).
- **Equivalence & laws:**
  - *Proof sketch:* Prove algebraic interval nesting: for $n \ge \lceil 2|x| \rceil$, $\frac{2|x|}{n+2} < 1$ gives `expLoAt x n ≤ expLoAt x (n+1) ≤ expHiAt x (n+1) ≤ expHiAt x n` (and $s_n - t_n > 1 > 0$ so reciprocals preserve nesting); for `log`, $|w| \le 1/3$ gives $T_n - T_{n+1} > |S_{n+1} - S_n|$. By `X5` ([X5.lean](kernel2/lean/Engine/X5.lean#L308-L477)), `nearestBits` is monotone per sign. Thus if $L \le \text{lo } m \le \text{hi } m \le U$ ($m \in [\text{first}, \text{last}]$) and `nearestBits L = nearestBits U = b`, then every deciding $n$ agrees on `b`, so `firstDeciding = b`. Without range reduction, $L \le \text{lo } m$ and $\text{hi } m \le U$ follow by elementary integer floor/ceil induction (zero real analysis; range reduction would additionally need an algebraic Cauchy-product bound).
  - *Law proofs:* Attached via `@[csimp]` — `X4` in [Laws.lean](kernel2/lean/Engine/Laws.lean#L1616-L1640) is **unchanged**.
- **Gain:** **1,000×–100,000× speedup** (~0.3–1 µs typical, ~15 µs at $|x|=700$ even without range reduction). Saves **1–6 h** on 212d 1-min replays with `log`/`exp` (**tens–hundreds of hours** at 1-s ticks / `x4_local`).

---

## 3. Event, Effect & Wish Queues: $O(N \cdot P)$ `insertPending` + Tail-Append Siblings
- **Where:** [MachineCore.lean](kernel2/lean/Engine/MachineCore.lean#L476-L514) (`insertPending`, `takeView` L501, `release`, `releaseEffects`), [emitOne](kernel2/lean/Engine/MachineCore.lean#L745-L750), [orderWishes / drain](kernel2/lean/Engine/MachineCore.lean#L807-L817), [tickBody L876](kernel2/lean/Engine/MachineCore.lean#L875-L877), [withPending](kernel2/lean/Engine/MachineCore.lean#L922-L923).
- **Current code & cost:**
  1. `insertPending` does list insertion sort on `s.pending` (FIFO tie-break: `p.known < q.known`). Because quotes and trades arrive with monotonically non-decreasing `known = time + δ`, **every quote/trade traverses and copies the entire `s.pending` list**! Step 3's admission benchmarks missed this because `s.prog = none` skips `withPending`.
     - *Real-scale cost:* Between ticks, `|pending|` holds every event in `tick + δ`. On 212d (229M quotes): at `tick = 60s, δ = 1s`, $P \approx 750\text{–}1{,}730$ → ~$1.5\text{–}3 \times 10^{11}$ cons allocations (**~1–1.5 h**); at `tick = 60s, δ = 120s`, $P \approx 2{,}500\text{–}5{,}200$ → ~$5.7 \times 10^{11}$ ops (**~2–4 h** on 212d, **~20–30 h** on 2y forward, busting the 24h wall); at `tick = 3600s` on book data, $P \approx 10^5$ (**~50–100 h**).
  2. Same pattern in sibling queues: `emitOne` L748 (`veffects ++ [x]`, $O(E_{\text{in-flight}}^2)$) plus two full `filter` passes in `releaseEffects` even though `veffects` is already sorted by `time + δ`; `orderWishes` L807–811 ($O(W^2)$ insertion sort on up to 256 wishes/tick already sorted by `(coin, slot)` at equal `arrives`) + `s.wishes ++ orderWishes sent`; `takeView` L501 (`cell.queue ++ [bits]`, $O(F^2)$).
- **Replacement:**
  - `pending`: **Binary min-heap** (`Array (Nat × Pending)` keyed by `(known, seq)` with monotonic `seq` for FIFO ties) — $O(1)$ on monotonic `known` push (zero swaps!), $O(\log P)$ pop and out-of-order push; safer than ad-hoc list sorting and $O(P)$ contiguous memory.
  - `veffects` & `wishes`: **FIFO circular queue** (or Okasaki two-list queue), exploiting proven timestamp monotonicity (`O(1)` push, `O(K)` drain).
  - `orderWishes`: Single linear **`List.partition (·.reduceOnly)`** (`r ++ nr`, $O(W)$).
  - `SrcCell.queue`: Prepend (`bits :: queue`) and reverse once in `sourceValue` before `total N`.
- **Equivalence & laws:**
  - *Proof sketch:* Lexicographic `(known, seq)` extraction matches `insertPending` + `span (·.known ≤ time)` identically (tie order preserved). Monotonicity of `time + δ` and `tick + λ` (already in `WishInv`) makes FIFO popWhile identical to `filter`/`takeWhile`. Since `sent` is generated in `(coin, slot)` order at one `arrives`, `partition` equals `orderWishes`. Reversing `SrcCell.queue` once preserves exact `total N` float fold order.
  - *Law proofs:* No frozen law statement in `Laws.lean` mentions `pending`, `veffects`, `wishes`, or `SrcCell.queue`. `C1` still holds directly; [Delivery.lean](kernel2/lean/Engine/Delivery.lean#L112-L145) (`PendSorted`/`Agree`) and `Clock`/`R1Closed`/`S1Closed` need ~100–150 lines of refactoring to project through `Heap.toSortedList`/`Queue.toList`.
- **Gain:** **1–4 h** saved on 212d 1-min replays (**20–30 h** on 2y forward at larger `δ`; **50–100 h** on hourly book replays).

---

## 4. Hot-Path Number Arithmetic: GMP `2^63` Trap, `Nat.pow`, & Redundant Divisions on 18.3B–39B Numbers
- **Where:** [Exact.lean](kernel2/lean/Engine/Exact.lean#L4-L5) (`natLog`), [L362 & L430–432](kernel2/lean/Engine/Exact.lean#L362-L432) (`dividesTen`, `onGridAt`), [L791–798](kernel2/lean/Engine/Exact.lean#L791-L798) (`nearestBits`), [L1158–1195](kernel2/lean/Engine/Exact.lean#L1158-L1195) (`readBitsFast`, `nearestBitsAt`, `roundScaled`); [MachineCore.lean](kernel2/lean/Engine/MachineCore.lean#L1008-L1018) (`word`, `signed`, `int64At`, `bitsAt`); [Num.lean](kernel2/lean/Engine/Lang/Num.lean#L87) (`bitsOps.finite`).
- **Current code & cost:**
  - **Lean 4 GMP trap:** Tagged unboxed `Nat` maxes at `2^63 - 1`; **`2 ^ 63` and `2 ^ 64` are always heap-allocated GMP bigints**. Thus:
    1. `readBitsFast` (18.3B calls in archive): `v % 2^63` and `2^63 ≤ v` invoke GMP on *every* double; `p.1 * 10^d` (80–93 bits), `2^(-E)` via `Nat.pow`, `roundScaled` GMP division, and `nearestBitsAt` (`Nat.log2`, two more GMP divisions + `%`) do **~6–8 GMP heap allocs, ~5 `Nat.pow`s, and ~4 GMP divisions per double** (~200–350 ns/double = **~1.0–1.8 h** over 18.3B archive doubles).
    2. `onGridAt` (9.15B archive / 19.5B forward prices, all `< 10^15 < 2^50`): non-tail-recursive `natLog 10` (up to 14 divisions) + up to 3× `Nat.pow 10` + `%` (**~25–40 min** archive, **~1–1.5 h** forward).
    3. `word`/`signed`/`bitsAt` (18.3B archive doubles; **78B `int64`s** in 2y forward strings): 8× `byteAt` + 15× `lean_nat_*` + GMP `2^63`/`2^64` (**~1–2 h** forward, **~15–30 min** archive).
    4. `bitsOps.finite` (every node × coin × tick): `a.toNat % 2^63 < infBits` allocates GMP bigints for every negative float and runs GMP `%` on every float!
    5. `nearestBits` (every `float(e)` crossing): recursive `natLog 2` + `Rat.zpow` + `Rat.div` instead of `Nat.log2` + shift (~1–3 h at 1-s ticks).
- **Replacement:**
  - `readBitsFast`: Pure unboxed `UInt64` + 2-word `UInt128` `(hi, lo)` + static `pow10` table + **direct midpoint interval check** (for `d ≤ 12`): we already hold `bits = ±M · 2^E` and `N = M · 10^d` (93 bits). By `X5`, `nearestBits(n / 10^d) == bits` iff `4|n|·2^(-E)` lies in `[4N - δ_lo·10^d, 4N + 2·10^d]` (closed iff `M` even, `δ_lo = 1` at `M = 2^52` else `2`) — **zero divisions, zero `nearestBitsAt`, zero `Nat.pow`, zero GMP** (~10–15 ns/double).
  - `onGridAt`: `UInt64` + static `pow10` table + standard Hacker's Delight `ilog10` (`clz`/`Nat.log2` + 1 table lookup/compare instead of 14 divisions).
  - `word`/`bitsAt`/`int64At`: Unboxed `UInt64` shifts (`|||`, `<<<`); `bitsOps.finite`: `(a &&& 0x7FFFFFFFFFFFFFFFUL) < 0x7FF0000000000000UL` (2 instructions).
  - `nearestBits`: `@[csimp]` twin via `Nat.log2`, bitshifts, and `roundDiv` (generalizing `nearestBitsAt`).
- **Equivalence & laws:**
  - *Proof sketch:* Midpoint check equivalence follows directly from `X5` (`nearestBits_ieee`, already proved in `X5.lean`); `±0`, NaN, ±∞, subnormals, and `d > 12` fall back or match exact bit cases. `UInt64` bitmask/shift lemmas are elementary `BitVec` identities.
  - *Law proofs:* All attach via `@[csimp]` — **zero changes to `X2`, `X3`, `X5`, `C2`, or any existing proof**.
- **Gain:** **~1.5–2.5 h** on 212d archive replay and **~2–3.5 h** on 2y forward replay (plus **1–3 h** on 1-s runs with `float(e)` crossings).

*(Part 2 covers Findings 5–9: per-quote `Rat`/`decodeWith` churn, `viewMarkAt` & `fireRec` quadratic/OOM bugs, `worldBook`/`arriveWish` rebuilds, OCaml CLI/archive OOM & `Decimal.place`, and quadratic `Ledger`/`xsRank`/`inspectChunk`.)*

PART 1 END

## Part 2

# Kernel Version 2 Efficiency & Simplicity Audit — Part 2

---

## 5. Per-Quote `Rat`/`gcd` & `decodeWith` Allocation Churn (229M–1.95B Quotes)
- **Where:** [MachineCore.lean](kernel2/lean/Engine/MachineCore.lean#L209-L212) (`ofUnits`, `midPrice`), [L488-L495](kernel2/lean/Engine/MachineCore.lean#L488-L495) (`takeView`), [L958-L964](kernel2/lean/Engine/MachineCore.lean#L958-L964) (`applyPayload`), [L1021-L1150](kernel2/lean/Engine/MachineCore.lean#L1021-L1150) (`readLevels`, `decodeWith`, `goAcc`, `feed`).
- **Current code & cost:**
  1. `feed` calls `decodeWith`, materializing a 2,048-element `List Event` where each quote allocates two `List Level`s (up to 40 `Level`s, 80 `Number` boxes, cons cells, and 2 `reverse`s ≈ 160 heap objects/quote). `goAcc`/`scanRest` immediately validates and discards all 38 non-best levels and every `Event` except `s.previous`.
  2. On every quote, `applyPayload` runs **3 `Rat` divisions** (`midPrice`, `ofUnits 8 bid/ask` — each evaluating `(10 : Rat) ^ 8` and GMP `gcd`), even in admission-only mode (`s.prog = none`). With a program, `withPending` runs **4 more `ofUnits`** (recomputing `bid`/`ask`), `takeView` L490 computes an **8th** `(bid + ask) / 2`, and `setAt s.coins` copies $O(C)$ cons cells.
  - *Real-scale cost:* On 212d archive (229M quotes): ~37B decode allocations + 0.69B–1.83B `Rat` divisions/`gcd`s (**~40 min–1.8 h**). On 2y forward (1.95B quotes): **~3–8 h**, hitting every book replay.
- **Replacement:**
  - **Two-phase zero-allocation streaming `feedFast` (`@[csimp]`):** Pass 1 validates chunk framing, bounds, `places ≥ 0`, and exact `integers`/`doubles` consumption with zero heap allocations; Pass 2 steps records directly from `ByteArray` offsets, materializing `Event` only for the last admitted record (`s.previous`).
  - Keep quote prices/sizes in `CoinState`, `PView.quote`, and `ViewCoin` as **scaled `Int`s** (prices at $10^8$; `hi`/`lo` at $2 \cdot 10^8$ where quote mid is `bid + ask` and print is `2 * p`), converting lazily at tick/row time via `mkRat n (pow10Nat scale)`. Store `coins`/`rules`/`view` as `Array`.
- **Equivalence & laws:**
  - *Proof sketch:* Pass 1 preserves `decodeChunk`'s exact all-or-nothing `"R_MARKET"` rejection before any state change or row emission; Pass 2 stops on the first `admit` error and sets identical `s.previous`. Common-denominator `Int` comparisons ($2 \cdot 10^8$) are order-isomorphic to `Rat` (`ofUnits_lt_iff` in [MachineFaults.lean](kernel2/lean/Engine/MachineFaults.lean#L76-L83)), and `mkRat` produces bit-identical reduced `Rat`s.
  - *Law proofs:* `feedFast` via `@[csimp]` leaves `C1`/`C2` unchanged; scaled-`Int` `CoinState`/`PView` adjusts ~25 lines in [DeliveryWorld.lean](kernel2/lean/Engine/DeliveryWorld.lean#L15-L47) and [Delivery.lean](kernel2/lean/Engine/Delivery.lean#L130-L145) (`L1a`); zero law statements change.
- **Gain:** **~40 min–1.8 h** on 212d archive (**~3–8 h** on 2y forward).

---

## 6. `viewMarkAt` $O(K C^2 Q)$ Rescan & `fireRec` Quadratic/OOM Bugs
- **Where:** [MachineCore.lean](kernel2/lean/Engine/MachineCore.lean#L466-L468) (`keepThrough`), [L663-L673](kernel2/lean/Engine/MachineCore.lean#L663-L673) (`tickCoin`, `viewMarkAt`), [L837-L915](kernel2/lean/Engine/MachineCore.lean#L837-L915) (`tickBody`, `fireRec`, `settle`), [L987-L989](kernel2/lean/Engine/MachineCore.lean#L987-L989) (`advance`), [L1162-L1167](kernel2/lean/Engine/MachineCore.lean#L1162-L1167) (`finishFull`).
- **Current code & cost:**
  1. `tickBody` computes `marks := s.coins.map (tickCoin s.cfg time)` (L840), then ignores it: `viewMark c` calls `viewMarkAt`, re-running `s.coins.map (tickCoin ...)` across **all $C$ coins** (scanning + copying `c.quotes` and formatting `c.price` via `fmtOpt`) on every exact-input AST node (`exactInput` evaluates `viewMark c` eagerly even for `pos`/`filled`!) plus 3 more times per coin in `rows`/`record`. With $K$ exact-input nodes, `tickCoin` runs $C + (K+3)C^2$ times per tick ($\Theta(K C^2 Q)$).
  2. `keepThrough` is non-tail-recursive over `c.quotes` (stack-overflow risk on large quote bursts).
  3. `fireRec` L899 appends **`recs ++ [record]`** ($\Theta(T_{\text{gap}}^2)$) and retains every full `TickRecord` (copying `mach.vals`/`exacts` and computing `fields` a second time), even though production `advance` and `finishFull` immediately discard `recs`!
  - *Real-scale cost:* On a 212d 1-min ladder ($K \approx 6\text{–}12$, $C=16$, $Q \approx 47$ quotes/coin/tick): $2{,}300\text{–}3{,}840$ `tickCoin`s/tick = $3.3\text{–}5.5 \times 10^{10}$ list ops (**~1–3 h**; **~3–8 h** at $\delta = 120\text{s}$; **~8–25 h** on 2y forward). In `fireRec`, a 1-day gap at 1-s ticks ($86{,}400$ ticks) copies $3.7 \times 10^9$ cons cells and pins **~4.3 GB of `TickRecord`s (OOM)**.
- **Replacement:**
  - Index the already-computed `marks` array in `tickBody` (`viewMark c := (marks[c]?.map (·.2.2.2)).getD false`), cutting `tickCoin` by $(K+3)C \approx 150\text{–}240\times$; replace `c.quotes` with a **FIFO queue** popping timestamps `≤ seen` ($O(1)$ amortized, zero stack risk).
  - Use a `settleNoRec`/`fireNoRec` path (zero `TickRecord` construction or list retention) for `advance`/`finishFull`; in proof-only `snapshots`, prepend `record :: recs` and reverse once.
- **Equivalence & laws:**
  - *Proof sketch:* `viewMarkAt` is definitionally `marks[c]?.map (·.2.2.2)`. [Clock.lean](kernel2/lean/Engine/Clock.lean#L275-L292) (`fireRec_gen`) already proves `fireRec`'s state and `Rows` never depend on `recs`, so `fireNoRec` matches `(fireRec ...).1, (fireRec ...).2.1` identically. Non-decreasing quote times make FIFO drain equal `find?`/`keepThrough`.
  - *Law proofs:* Zero law statements change. `settleNoRec` via `@[csimp]` keeps `C1`/`L1a`/`X1`/`R1`/`S1` proofs untouched; `marks` reuse + FIFO `quotes` adjusts ~25 lines in [Delivery.lean](kernel2/lean/Engine/Delivery.lean#L287-L377).
- **Gain:** **1–8 h** on 212d ladder (**8–25 h** on 2y forward); eliminates **multi-GB OOM** on gaps/1-s/sparse runs.

---

## 7. `worldBook`, `viewBook`, & `arriveWish` Redundant Rebuilds
- **Where:** [MachineCore.lean](kernel2/lean/Engine/MachineCore.lean#L553-L579) (`buildBook`, `worldBook`, `viewBook`, `equityAt`), [L602-L620](kernel2/lean/Engine/MachineCore.lean#L602-L620) (`ownInput`), [L760-L789](kernel2/lean/Engine/MachineCore.lean#L760-L789) (`arrivalEffects`, `arriveWish`), [L814-L817](kernel2/lean/Engine/MachineCore.lean#L814-L817) (`drain`); [Orders.lean](kernel2/lean/Engine/Orders.lean#L91-L214) (`committed`, `sameOrder`, `arrive`); [World.lean](kernel2/lean/Engine/World.lean#L58-L106) (`Acct.live`, `Acct.apply`).
- **Current code & cost:**
  1. `arriveWish` eagerly computes `arrive`, `cancelSlot`, `prepare`, and `admitted` before `withLog` (dead work when `s.log = none`), then `arrivalEffects` re-runs `arrive`, `cancelSlot`, and `prepare` a **second time** — invoking `roundedPrice`/`roundedTarget` (`Rat` `ilog 10`/`gridStep`) 4–6× even on steady-state no-op wishes.
  2. `drain` calls `worldBook` ($\Theta(C^2 + L(C+S))$ via `List.getD` + per-order `remainder`) for every wish in a timestamp's batch (up to $W = C \cdot S = 256$), even though marks, positions, cash, leverages, taker rates, `positionMargin`, and `equity` cannot change across same-timestamp wishes.
  3. `ownInput` recomputes account-wide `equityAt` ($O(C^2)$) and `(viewBook s time).freeMargin` ($O(C^2 + L(C+S))$) separately for every coin $c$ at every tick.
  - *Real-scale cost:* $\Theta(W(C^2 + L(C+S)))$ per deciding tick. A 7-slot × 16-coin ladder runs 34M arrivals in 212d 1-min (**~6–17 min**), 118M in 2y (**~20–60 min**), and 2.05B at 1-s (**~6–17 h**; 16 slots: **~25–70 h**).
- **Replacement:**
  - Deduplicate `arriveWish`/`arrivalEffects` (gate log-only bindings on `s.log.isSome`; round price/target once per wish).
  - Batch same-timestamp wishes in `drain`: compute immutable per-timestamp `Array`s (`marks`, `positions`, `leverages`, `takerRates`, `positionMargin`, `equity`) once per timestamp, index live orders in a flat $C \times S$ array ($O(1)$ lookup/cancel), and update exact `committed` incrementally ($O(1)$). Cache `viewEquity`/`viewFreeMargin` once per tick in `tickBody`.
- **Equivalence & laws:**
  - *Proof sketch:* `arriveWish_frame` ([Clock.lean](kernel2/lean/Engine/Clock.lean#L172-L174)) shows wishes never alter cash, positions, marks, rules, or fees. Exact `Rat` addition is commutative and associative, so incremental `committed` equals `Admission.requirement` identically (preserving `margin`/`minimum`/`cap` refusal order).
  - *Law proofs:* Attached via `@[csimp]` on `drain`/`tickBody` — **zero proof changes** to `R1`, `S1`, `X1`, or `L1a` (direct `arriveWish` CSE alone touches ~15 lines in `DeliveryWorld`/`PlacedLaw`/`RunSim`).
- **Gain:** **~6–17 min** (212d 1-min), **~20–60 min** (2y 1-min), **~6–17 h** on 212d 1-s replays.

---

## 8. OCaml CLI/Archive OOM (`mm2.ml`, `reader.ml`) & `Decimal.place` Churn
- **Where:** [mm2.ml](kernel2/ocaml/bin/mm2.ml#L64-L146) (`feed`, `unhex`, `load`, `finish`), [reader.ml](kernel2/ocaml/archive/reader.ml#L205-L211) (`run_streams`), [L432-L601](kernel2/ocaml/archive/reader.ml#L432-L601) (`trade_file`, `events_of_chunk`, `merge`), [decimal.ml](kernel2/ocaml/src/decimal.ml#L20-L40) (`place`), [stubs.c](kernel2/ocaml/src/stubs.c#L159-L169) (`mm2_stub_machine_feed`).
- **Current code & cost:**
  1. `mm2 feed` appends hex/JSON chunks to `state_path`; `mm2 finish` slurps the whole file into RAM (`load`), decodes records via allocating `unhex` (48 strings/record), and buffers the **entire** `report` and `trace` in RAM (`Buffer.t` + `Buffer.contents` copy) instead of streaming to spool files (B2/A19). Even 1 day (~3.8 GB JSON + multi-GB trace) **OOMs**.
  2. `Reader.trade_file` slurps an entire JSONL day, parses every row via `Yojson`, encodes all trades into lists, then slices via non-tail-recursive `take` (~4–6 GB on busy days = **OOM**).
  3. `Reader.merge` materializes every event of every stream into one `event list` (converting flat arrays with `Array.to_list`), runs `List.stable_sort`, and returns one monolithic chunk (~6–8 GB/day, >500 GB/212d = **OOM**).
  4. `Decimal.place` allocates up to 7 intermediate strings over 5–6 scans per decimal, followed by `Int64.of_string` (which throws on overflow). On 2y forward's **39B quote strings**: ~200 ns × 39B ≈ **~2.2 h** and ~270B heap strings. `stubs.c` double-copies `integers` (`malloc` + `lean_bytes`).
- **Replacement:**
  - Stream `mm2` rows to private `.report.spool`/`.trace.spool` files (atomic rename only on `ok: true`); stream binary-framed chunks without holding history; table-driven `unhex`.
  - Stream `trade_file` line-by-line into a 2,048-event `builder`.
  - Replace `Reader.merge` (and `run_streams`'s linear scan) with a **streaming $k$-way merge via a binary min-heap** over indexed flat-array cursors ($O(N \log K)$ time, $O(K \cdot \text{chunk})$ RAM).
  - Single-pass zero-allocation index scanner in `Decimal.place` (plus `Decimal.place_int64` accumulating `int64` directly with overflow check); unbox `integers` straight into `lean_sarray_cptr` in `stubs.c`.
- **Equivalence & laws:**
  - *Proof sketch:* OCaml/C trust boundary (equivalence is testable, not Lean-proved). Keying the min-heap by `(key, stream_idx, event_idx)` preserves `List.stable_sort` order on A3-sorted input streams; atomic spool rename preserves A13/W1; single-pass `Decimal.place` matches the exact grammar and zero-trimming (differential-testable via `exact_test.ml`/QuickCheck).
  - *Law proofs:* **None** (outside Lean).
- **Gain:** Fixes **guaranteed OOM** in `mm2 finish`/`merge`/`trade_file` (**>4–500 GB → <50 MB**); saves **~1.8–2.2 h** on 2y forward string parsing.

---

## 9. Quadratic `Ledger.replay`/`checkFunding`, `xsRank`, & `inspectChunk`
- **Where:** [Ledger.lean](kernel2/lean/Engine/Ledger.lean#L119-L144) (`replayStep`, `replay`, `checkFunding`), [Eval.lean](kernel2/lean/Engine/Lang/Eval.lean#L168-L214) (`rank`, `nodeCore`), [MachineWire.lean](kernel2/lean/Engine/MachineWire.lean#L64-L79) (`quoteTimes`, `inspectChunk`).
- **Current code & cost:**
  1. `Ledger.replayStep` calls `receipts.getLast?` and `receipts ++ [receipt]` per event ($\Theta(N^2)$, direct sibling of `Machine.go`): 100k–500k fills/funding copy ~$10^{10}$–$10^{11}$ cons cells (**~30–60 min**).
  2. `Ledger.checkFunding` nests `held.any (... events.any ...)` ($\Theta(|H| \cdot |E|)$): 81k–300k obligations × 181k–1M events = $1.5 \times 10^{10}$–$3 \times 10^{11}$ checks (**~5 min–2 h**).
  3. `nodeCore` runs `xs.find? (·.1 == c)` for all `xs*` ops ($\Theta(C^2)$), computes unused `mean` for `xsRank`, and `rank` allocates two `List.filter` copies per coin ($\Theta(C^2)$): **~10–30 min** at 1-s ticks (hours at $C \ge 100$).
  4. `inspectChunk` decodes every level/double via `decodeWith`, then rescans `events` $C$ times via `quoteTimes` ($\Theta(N \cdot L_{\text{levels}} + C \cdot N)$): **~20–40 min** across 212d.
- **Replacement:**
  - `Ledger.replay`: tail-recursive `(state, revReceipts)` accumulator + one `reverse` ($\Theta(N)$).
  - `Ledger.checkFunding`: collect valid funding `(coin, hour)` pairs in a **sorted array / `Std.TreeSet`** (or `Std.HashSet`), then query `held` in $O(\log |E|)$ / $O(1)$.
  - `xs*`: index `(argRows 0)[c]!` directly ($\Theta(C)$ for `xsMean`/`xsDemean`), skip `mean` for `xsRank`, and use **sort + tie-group sweep** ($O(C \log C)$) for `bitsOps` `xsRank`.
  - `inspectChunk`: Pass-1 structural pre-scan + single-pass online `staleSpans` over a size-$C$ `Array` ($\Theta(N + C)$).
- **Equivalence & laws:**
  - *Proof sketch:* Accumulator+`reverse` equals `foldl (· ++ [·])`; tree/set lookup equals `events.any`; direct `(argRows 0)[c]!` equals `xs.find?`; sort+tie-sweep computes exact `below`/`equal` counts on finite IEEE doubles (a strict weak order guaranteed by `finalize`); online per-coin fold equals `quoteTimes` + `staleSpans`.
  - *Law proofs:* Attaching `replayFast`/`checkFundingFast`/`xsRankFast` via `@[csimp]` leaves **`A1`, `U1`, `L2`, `L3`, `N1` proofs unchanged** ([Laws.lean](kernel2/lean/Engine/Laws.lean#L248-L358); direct `xs.find?` removal also preserves `RenameProofs`/`RewriteProofs` unchanged); `inspectChunk` has no law.
- **Gain:** **~30 min–2 h** on full `Ledger` replays; **~10–30 min** on 1-s `xsRank`; **~20–40 min → ~4 s** on 212d `inspectChunk`.

---

## Ranked Summary of All Nine Findings

| Rank | # | Finding | Real-Replay Gain (Time / RAM) | Lean Law Proof Changes? |
|---:|---:|---|---|---|
| 1 | 1 | Rolling windows (`Win.push`) & `Mach.step` RC CoW | **Hours–days → s**; max-window RAM **>2.5 GB (OOM) → 160–300 MB** | **No** via `@[csimp]` on `Mach.step` (or ~40 lines in `EvalProofs` for `L2`/`L3`/`N1`) |
| 2 | 2 | Transcendentals `exp`/`log` (X4 big-int `Rat`) | **1–6 h** (212d 1-min) / **40–400 h** (1-s) → **s** (1,000×–100,000×) | **No** (`@[csimp]` twins; `X4` unchanged) |
| 3 | 3 | `insertPending` & sibling queues (`veffects`/`wishes`/`queue`) | **1–4 h** (212d); **20–30 h** (2y, large `δ`); **50–100 h** (hourly book) | **Yes** (~100–150 lines in `Delivery`/`Clock`/`R1Closed`/`S1Closed` for `L1a`/`R1`/`S1`; `C1` unchanged) |
| 4 | 4 | Hot-path arithmetic (GMP `2^63`, `readBitsFast`, `onGridAt`, `word`, `finite`, `nearestBits`) | **1.5–2.5 h** (212d); **2–3.5 h** (2y); **+1–3 h** on 1-s `float(e)` | **No** (`@[csimp]`; `X2`/`X3`/`X5`/`C2` unchanged) |
| 5 | 6 | `viewMarkAt` $O(K C^2 Q)$ rescan & `fireRec` quadratic/OOM | **1–8 h** (212d ladder) / **8–25 h** (2y); fixes **>4 GB OOM** on long gaps | **Minimal** (`settleNoRec` via `@[csimp]` = 0; `marks` + FIFO `quotes` ≈ 25 lines in `Delivery` for `L1a`) |
| 6 | 5 | Per-quote `Rat`/`gcd` & `decodeWith` churn | **40 min–1.8 h** (212d); **3–8 h** (2y forward) — every book replay | **Minimal** (`feedFast` via `@[csimp]` = 0; scaled-`Int` state ≈ 25 lines in `Delivery`/`DeliveryWorld` for `L1a`) |
| 7 | 8 | OCaml CLI/archive OOM (`mm2.ml`, `reader.ml`) & `Decimal.place` | Fixes **guaranteed OOM** (**>4–500 GB → <50 MB**); **1.8–2.2 h** (2y strings) | **No** (OCaml/C boundary only) |
| 8 | 7 | `worldBook`/`viewBook`/`arriveWish` rebuilds | **6–17 min** (212d 1-min); **20–60 min** (2y 1-min); **6–17 h** (212d 1-s) | **No** via `@[csimp]` on `drain`/`tickBody` (direct CSE ≈ 15 lines in `DeliveryWorld`/`PlacedLaw`/`RunSim`) |
| 9 | 9 | Quadratic `Ledger.replay`/`checkFunding`, `xsRank`, `inspectChunk` | **30 min–2 h** (`Ledger`); **10–30 min** (1-s `xsRank`); **20–40 min → 4 s** (`inspect`) | **No** (`@[csimp]` keeps `A1`/`U1`/`L2`/`L3`/`N1` unchanged; `inspectChunk` has no law) |

*No frozen law statement changes under any of the nine replacements.*
