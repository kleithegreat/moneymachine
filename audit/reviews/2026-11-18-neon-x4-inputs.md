# Neon on kernel v2 step 5 test 12's inputs (the exp/log draws, certification, glibc list, loopholes)

Model `gemini-4-neon-xhigh` through agy, from a clean folder holding only the bundle `x4-inputs.md` (test 12's files, the `last_pass_r3` recipe, X4 and X5, brief 3 step 5, CORE-MATH's source note and headers). Neon passed its blind calibration the same day. The reply, verbatim:

### 1. The mismatch

- **Which side should change:** Change the **recipe** (not the test's 1,000,000 count).
  - Brief 3, step 5, test 12 explicitly prescribes *"a million random finite arguments of each, drawn as `arithmetic.py.txt`'s `last_pass_r3` draws them."* `last_pass_r3` was an exploratory audit snippet (200,000 draws, slow 60-digit `Decimal` checking, stdout-only, plus unrelated ledger/bootstrap code) — it writes no files, so a file-emitting generator is needed either way.
  - Keeping 1,000,000 also preserves ~5× more glibc `exp` mis-roundings (~720 vs ~144) and increases the chance of finding any `log` mis-rounding (0 in 200,000).
  - **Provenance fix:** Do not pin an unmodified 200,000-draw `arithmetic.py.txt` as `recipe_sha256` while claiming it generated 1,000,000-line files. Either add an explicit emitter mode/helper to `arithmetic.py.txt` (preserving the 200k report as default if needed, and running it with `count = 1_000_000`) or point both `manifest.json`'s `recipe`/`recipe_sha256` and `x4_local.ml` at the exact pinned generator script.

- **Exact reproducible recipe:**
  - **Generator & seed:** CPython 3 (pinned from `nixpkgs`) `random.Random(5)` (MT19937, integer seed `5`).
  - **Crucial interleaving:** **One single PRNG instance**, drawing `exp` and `log` interleaved in one loop of `1,000,000` iterations (preserving exact bit-identity with `last_pass_r3` on the first 200,000 pairs):
    ```python
    draw = random.Random(5)
    for _ in range(1_000_000):
        x = draw.uniform(-700.0, 700.0)                                # 1st: exp draw
        y = math.ldexp(1.0 + draw.random(), draw.randrange(-995, 995)) # 2nd: random(), 3rd: randrange()
    ```
    Note Python's left-to-right argument evaluation: per iteration, `draw.uniform(-700.0, 700.0)` consumes 1 `random()`, then `1.0 + draw.random()` consumes the next `random()`, then `draw.randrange(-995, 995)` consumes `getrandbits(11)` (rejection-sampled to `< 1990`).
  - **Distributions, ranges, and counts:**
    - `exp-draws.txt`: `1,000,000` finite values, linearly uniform in `[-700.0, 700.0)` (computed as `-700.0 + 1400.0 * draw.random()` in IEEE binary64 RNE).
    - `log-draws.txt`: `1,000,000` finite positive normal values, binade-uniform over `e ∈ {-995, …, 994}` with significand `m = 1.0 + draw.random() ∈ [1.0, 2.0]` (so `y ∈ [2^-995, 2^995]`; note `1.0 + k·2^-53` rounds ties to even, giving even significands 3× the weight of odd ones and `m = 2.0` with probability `2^-53`).
  - **File format read by `x4_local.ml`:**
    - `exp-draws.txt`, `log-draws.txt`: `1,000,000` LF-terminated lines each, no comments/blank lines/prefix, each line a **16-character lowercase zero-padded hex** IEEE binary64 bit pattern (`f"{struct.unpack('>Q', struct.pack('>d', v))[0]:016x}"`).
    - `exp-glibc.txt`, `log-glibc.txt`, `boundaries.txt`: same 16-char lowercase hex format (one per line; `boundaries.txt` has 6 lines in `O.boundaries ()` order).
    - `hardest.txt`: one entry per line as `exp <16-hex>` or `log <16-hex>` (single ASCII space; CORE-MATH's `#` comments and C hexfloats must be stripped/converted to raw 64-bit hex).
    - `manifest.json` + `SHA256SUMS` (two spaces `<sha256>  <filename>\n` covering all 7 files).

- **Does this distribution exercise what X4 and X5 need?** **No — only partially.**
  - **Both signs:** Yes for `exp` arguments (`[-700, 700)`, exercising both `S ± T` and `1/(S ± T)`) and for `log` results (`e ∈ [-995, 994]` gives ~50% negative, ~50% positive `log(y)`). `exp` results are always positive and `log` draws are always positive.
  - **Subnormal edge:** **Completely missed.** `exp` subnormal outputs lie in `(-745.133, -708.396)` — `exp-draws.txt` stops at `-700.0`. `log` subnormal inputs lie in `e ∈ [-1074, -1023]` (where X4's `|e|·B(1/3)` is largest) — `log-draws.txt` stops at `e = -995`. Subnormal `exp` inputs and `|x| ≪ 1` are also essentially never hit (`P(|x| < 2^-20) ≈ 1.4 × 10^-9`).
  - **Overflow / extreme-exponent edge:** **Completely missed.** `exp` overflows at `≈ 709.7827` (X4 cutoff `710`), but draws stop at `+700.0`. `log` draws stop at `e = 994`, missing the top 29 binades `[995, 1023]` up to `DBL_MAX` (`e = 1024` after `[3/4, 3/2)` normalization), and almost never hit `|y - 1| ≪ 1`.
  - **Ties / hard-to-round cases:** **Missed.** By Lindemann–Weierstrass, `exp(x)` (`x ≠ 0`) and `log(y)` (`y ≠ 1`) at dyadic rationals are transcendental, so exact midpoints never occur; 10^6 random draws only reach ~`2^-20` of a midpoint (~74 bits), nowhere near X4's `2^-256` cap. X5's exact ties, negative underflow to `-0`, subnormal/normal boundary, and overflow threshold are **not** exercised by `last_pass_r3` at all — they rely entirely on `x4_local.ml`'s separate `nearest ()`, `boundaries.txt`, `specials`, and `hardest.txt`.

---

### 2. Certification

- **Is CORE-MATH's list adequate to certify "correctly rounded everywhere"?**
  **No as a standalone certification of totality; yes as an empirical hard-case test corpus** — and separate the two claims:
  1. **Correct rounding whenever defined:** Already guaranteed by X4 + X5 (Lean-proved `nearestBits` + textbook rational-interval enclosure, tested against MPFR), **not** by CORE-MATH's list. Missing a hard-to-round input can never produce a wrong rounding, only X4's cap NaN (undefined).
  2. **No cap NaN anywhere in the finite domain:** CORE-MATH's `exp.wc` and `log.wc` are **test-vector dumps**, not a formal or self-contained exhaustiveness certificate. Their own headers use hedged language (*"for most inputs"*, *"we should have all worst cases with 47 identical bits or more"*, *"some tests"*, *"additional worst cases"*, plus a garbled range comment `[-2^-11,-2^-11)` and AI-generated coverage inputs) and do not specify complete binade-by-binade domain bounds or provide a proof of completeness. Moreover, the underlying Table Maker's Dilemma searches (Lefèvre's `hrcases`, Zimmermann's BaCSeL) are unverified C/lattice-reduction computations, not mechanized Lean proofs. That said, the published binary64 TMD bounds sit well above X4's cap widths (`< 2^-258` relative for `exp`, `< 2^-294` relative for `log`), so testing these files gives strong empirical evidence.

- **What it covers and doesn't cover:**
  - **Covers:**
    - **`exp` subnormal outputs:** **Yes.** `exp.wc` explicitly includes `exp(x) ~ 2^-1075` (line 68082), ad-hoc subnormal-output tests (line 68084), ~72k BaCSeL subnormal-output worst cases at `-m 34` (≥33 identical bits after the round bit, lines 68095–140355), and additional subnormal hard cases (line 1129472).
    - **`exp` overflow/underflow edges:** **Yes.** `exp.wc` includes overflow/underflow edge inputs (lines 21, 68082, 1111196). Furthermore, because `exp` is strictly monotone, each of the three single thresholds (`log((2-2^-53)2^1023)`, `log(2^-1022 - 2^-1075)`, `-1075 log 2`) has **only two** closest binary64 inputs, which `boundaries.txt` tests exhaustively.
    - **`exp` normal outputs:** BaCSeL hard-to-round cases (mostly `-m 42`, `-m 44` near `-2^-11`, `-m 25` for `exp(x) ∈ [2^-1022, 2^-1021)`), signed zero, special values, errno and non-regression cases.
    - **`log`:** Lefèvre's `hrcases-explog.xz` worst cases (~6,349 entries), BaCSeL cases targeting ≥47 identical bits after the round bit (~128,592 entries), special values, errno and coverage cases.
  - **Does not cover / does not certify:**
    - No certified exhaustive domain specification inside `exp.wc` (it does not document whether every normal/subnormal output binade and tiny/subnormal input binade of `exp` was exhaustively swept, nor the global max run length).
    - `log.wc`'s header does not state whether subnormal inputs `y ∈ [2^-1074, 2^-1022)` were exhaustively included in the `-m 48` BaCSeL sweep (as opposed to normal inputs only).
    - No mechanized proof that no unsearched input comes within `2^-256` of a midpoint.
    - Note also a conversion hazard: both `.wc` files contain non-finite `# special values` (`Inf`, `NaN`) and `errno` inputs (negative `log` inputs) in C hexfloat syntax; the conversion to `hardest.txt` must document exactly what was kept/converted.

- **What `manifest.json`'s `certification` string should say:**
  Be concrete, pinned, and honest about scope and limits — for example:
  > `CORE-MATH binary64 worst-case tables (gitlab.inria.fr/core-math/core-math @ 1851882b0f85ed581af9185cfa020992cec9e7a1): src/binary64/exp/exp.wc (BaCSeL normal-output cases mostly >=41 identical bits after round bit, subnormal-output cases >=33 bits, overflow/underflow/special/regression cases) and src/binary64/log/log.wc (Lefevre hrcases-explog + BaCSeL >=47 bits + special cases), converted from hexfloat to raw IEEE binary64 bits. Empirical/computational TMD test corpus, not a mechanized exhaustiveness proof; full binade coverage of exp subnormal outputs and log subnormal inputs is uncertified beyond the cited search headers. Correct rounding of every defined result follows from X4+X5; any harder uncertified input could only yield X4's cap NaN (undefined), never a mis-rounding.`

---

### 3. The stub's outputs

- **The six boundary words from `mm2_test_mpfr_boundaries` (in order) and whether they are right:**

  | Index | Threshold & direction | Exact 64-bit hex | `exp` result |
  |---|---|---|---|
  | `0` | `RNDD(log((2 - 2^-53)·2^1023))` | `40862e42fefa39ef` | Finite (`< DBL_MAX`, largest binary64 with finite `exp`) |
  | `1` | `RNDU(log((2 - 2^-53)·2^1023))` | `40862e42fefa39f0` | `+∞` (smallest binary64 whose `exp` overflows) |
  | `2` | `RNDD(-1022·log 2)` | `c086232bdd7abcd3` | Subnormal (`000ffffffffffe7c`, largest binary64 with subnormal `exp`) |
  | `3` | `RNDU(-1022·log 2)` | `c086232bdd7abcd2` | Normal (`> 2^-1022`, smallest binary64 with normal `exp`) |
  | `4` | `RNDD(-1075·log 2)` | `c0874910d52d3052` | `+0` (`0000000000000000`, largest binary64 underflowing to `0`) |
  | `5` | `RNDU(-1075·log 2)` | `c0874910d52d3051` | `2^-1074` (`0000000000000001`, smallest binary64 with nonzero `exp`) |

  - **Are they right?** **Yes, all six words are exact and bracket the true rounding transitions.**
  - **One mathematical caveat on `i = 1`:** The true subnormal/normal rounding midpoint is `log(2^-1022 - 2^-1075) = -1022·log 2 + log(1 - 2^-53)`, not `-1022·log 2` (`log(min_normal)`). Because the shift is only `2^-53 = 2^-10` ULP while `-1022·log 2` sits `0.2417` ULP below `c086232bdd7abcd2`, both points fall in the exact same binary64 ULP (`0.2417` vs `0.2427`), so the stub returns the right pair `c086232bdd7abcd3` / `c086232bdd7abcd2` anyway (matching Brief 3's `-1022 log 2`). Computing `log((1 - 2^-53)·2^-1022)` explicitly would make `i = 1` consistent with `i = 0` and `i = 2`.

- **How to compute "every glibc mis-rounding among the draws" so two hosts agree:**
  - Two hosts disagree because glibc's `libm` depends on **glibc version/build, CPU architecture, and runtime IFUNC CPU dispatch** (e.g., FMA vs AVX2 vs SSE2 on x86_64 — the very reason `x4-hosts.sh` tests `-FMA`).
  - To make `exp-glibc.txt` / `log-glibc.txt` deterministic across hosts:
    1. Evaluate the 1,000,000 `exp-draws.txt` and 1,000,000 `log-draws.txt` using the **pinned `nixpkgs` glibc** (`x86_64-linux`) against the **pinned MPFR stub (`mm2_test_mpfr`)** (not Python `decimal`), with the exact predicate `finite glibc && finite mpfr && glibc <> mpfr`.
    2. **Pin the IFUNC dispatch path** via `GLIBC_TUNABLES=glibc.cpu.hwcaps=-FMA,-AVX,-AVX2,-AVX512F` (baseline x86_64 SSE2, which executes identically on *every* x86_64 host regardless of hardware FMA/AVX support) — or, if you want the file to witness mis-roundings from multiple paths (e.g., FMA and `-FMA`), compute the **sorted, deduplicated union** over an explicitly pinned list of `GLIBC_TUNABLES` paths on a host supporting them, and record the exact `nixpkgs` glibc derivation/version and `GLIBC_TUNABLES` value(s) in `manifest.json`.
    3. Preserve deterministic order (e.g., draw order or sorted unique hex), pin the resulting files and counts (`exp_glibc_count`, `log_glibc_count`) in `manifest.json` and `SHA256SUMS`. Both hosts in `x4-hosts.sh` then consume the same pinned files without depending on local glibc behavior.

---

### 4. Loopholes that let a wrong engine pass test 12

1. **Non-finite outputs (`+∞`, `-∞`, `NaN`, and X4's cap `NaN`) are all collapsed to `None` (`"-"`) (`x4_local.ml:115-120, 147-157`).**
   - Because `expected` maps every non-finite MPFR output to `None` and the probe trace renders every non-finite node as `"-"`, an engine that returns **`NaN` (including X4's cap NaN!) or `-∞` instead of `+∞`** at `exp(40862e42fefa39f0)`, `exp(710)`, `exp(+∞)`, or `log(+∞)` — or returns **`NaN`/`+∞` instead of `-∞`** at `log(±0)`, or **`±∞` instead of `NaN`** at `log(-1)` or `exp(NaN)` — **passes test 12**.
   - In particular, hitting X4's cap NaN on any overflowing finite input `x ∈ [40862e42fefa39f0, 710)` passes silently despite the check message `"no finite-domain result is X4's cap NaN"`.

2. **The engine is linked into the same binary as MPFR (`x4_local.exe`) with no symbol/linkage check.**
   - `x4_mpfr_stubs.c` claims *"No engine object links MPFR,"* but neither `x4_local.ml` nor `x4-hosts.sh` inspects the engine archive/library (`nm -u` / `ldd`). An engine that calls `mpfr_exp`/`mpfr_log`/`mm2_test_mpfr` (resolved at link time by `x4_local.exe`'s own `-lmpfr`), or calls CORE-MATH/CRlibm/a lookup table instead of X4's Lean formula, **passes test 12 completely**.

3. **`exp-glibc.txt` and `log-glibc.txt` are completely unverified (`x4_local.ml:215-230`).**
   - `x4_local.ml` computes `actual` (the host's glibc-vs-MPFR mismatch count) and **discards it** after logging to stderr; it never checks that `listed` is a subset of `values`, finite, non-empty when `actual > 0`, or actually contains glibc mis-roundings. Setting `exp_glibc_count = 0` / `log_glibc_count = 0` with empty files passes. (Even when populated, `values @ listed` only re-runs elements already in `values`.)

4. **Self-attesting `INPUT_DIR` and weak validation (`x4_local.ml:181-240`).**
   - `SHA256SUMS` is verified only against itself, not against a root hash pinned in the test or script.
   - `recipe_sha256` only checks `String.length = 64` (not hex, not hashed against `arithmetic.py.txt`); `certification` only checks `<> ""`; `exp-draws.txt` / `log-draws.txt` only check `1,000,000` finite hex words (1,000,000 copies of `0000000000000000` pass); `hardest.txt` only checks `<> []` (a single line `exp 0` passes — it doesn't even enforce 16-char hex, finiteness, or presence of both `exp` and `log` entries).
   - `Filename.check_suffix line ("  " ^ file)` (`x4_local.ml:190`) can even be satisfied by a differently named file containing two spaces (e.g., `dummy  exp-draws.txt`), leaving the real file unhashed.

5. **Domain blind spots in `draws` + `boundaries` + `specials` (if `hardest.txt` is sparse or omits them).**
   - None of `exp-draws.txt`, `log-draws.txt`, `boundaries.txt`, or `specials` contains: any **subnormal input** (`2^-1074`, `max_subnormal`, testing `log`'s `|e| = 1074` and subnormal decoding), `min_normal`, `±DBL_MAX` (`log`'s `e = 1024`), `1 ± eps` (`0x3fefffffffffffff`, `0x3ff0000000000001`), tiny negative `exp` inputs (`-2^-54`, `-2^-53`, `-2^-1074`), or signaling NaNs (`0x7ff0000000000001`). A buggy `log` decoder on subnormal or `|e| > 995` inputs passes all 2,000,000 draws + `boundaries` + `specials`.
   - `exp` on `x` between `40862e42fefa39f0` and `710` (and between `-746` and `c0874910d52d3052`) is untested except at the endpoints; e.g., an engine with wrong `-746`/`710` cutoffs (still outside `[-745.1332, 709.7827]`) or broken at `nextafter(-746.0, 0)` (where X4's `N` is maximized) passes.

6. **`x4-hosts.sh` cross-host and `-FMA` loopholes (`x4-hosts.sh:541-563`).**
   - Never verifies that `HOST1` and `HOST2` have the **same** `$exe` binary, linked engine library, or `$inputs/SHA256SUMS` hash.
   - Checking only `/etc/machine-id` allows two identical VMs/containers on the **same** CPU (or two hosts without FMA / non-x86_64 hosts where `GLIBC_TUNABLES=glibc.cpu.hwcaps=-FMA` is silently a no-op; `GLIBC_TUNABLES` is also ignored on `AT_SECURE` binaries).
   - Does not vary floating-point rounding mode (`FE_UPWARD`/`FE_DOWNWARD`/`FE_TOWARDZERO`) or FTZ/DAZ (left to step 9 test 8), so an engine relying on host FP rounding mode passes test 12.
   - `x4-counts.lean` runs only locally via `orders-crossings.sh` on Lean's formulas, decoupled from the engine binary tested in `x4_local.exe`, and (per `x4_local.ml:47`) may only inspect `boundaries.txt` rather than all inputs — so an engine diverging from X4's term-count/twin implementation on untested inputs or hitting higher term counts isn't caught by it.

7. **Minor `nearest ()` spec-check gaps (`x4_local.ml:78-113`).**
   - `k = 0` only uses tiny ~52-bit denominators (`d ≈ 2^52`) and never tests `midpoint ± ε` (near-ties right next to subnormal/normal midpoints or `2^-1075 ± ε`), only exact midpoints (`k = 1, 2, 3`, with just 4 subnormal midpoints in `k = 2`) and `±2^960` at overflow (`k = 4`). Also `mm2_test_mpfr_rational` casts 54-bit constants to `unsigned long` (safe on LP64 Linux, silently truncates on 32-bit/LLP64).
