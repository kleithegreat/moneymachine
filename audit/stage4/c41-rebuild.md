# C4.1 rebuilt on `canon::rules()`, 2026-11-08 (Sonnet builder), for the final stage 4 review

Branch `stage4-c41`, test commit below. Items 1 to 3 of `audit/reviews/2026-11-08-opus-stage4-exit.md`; exit.md, the paper and "done" are untouched.

**C4.1.** `kernel/mm/tests/rules.rs` no longer holds a copy of R. `rewrites()` lowers the tree to the e-graph `canon::term` builds, takes each match from the rule's own searcher, lets its own applier decide the condition, and instantiates its right side from the match (kept subtrees keep their tags). The comparison harness is unchanged. The generator's programs and seeds are unchanged, but the matching positions now come from R's forward rules (if-not's reverse direction, never a rule, is gone), so `GENERATED_DIGEST` is re-pinned to `606e7821…`. The three rules with a fixed constant are also tried over every right operand in the signed-zero test, so a widened condition has cases to fail on.

Mutants, applied to `src/canon.rs` and reverted (all in `rules` unless noted):
- m2 (`if-not` keeping branch order): fails, `if-not id operands 0,2 on N1+zeros`.
- m3 (`abs-neg` to `?x`): fails, `abs-neg id operands 3,0 on N1+zeros`.
- sub-zero's condition always true: fails, `sub-zero id any right operand 0,2 on N1+zeros`.
- mul-one's constant changed to 0: fails, `mul-one id any right operand 2,0 on N1+zeros`.
- **m1 (sub-zero accepting a −0 constant) cannot fail, and the review's reasoning for it does not hold:** `dsl.rs:451` stores constants as `(x + 0.0).to_bits()`, so no program has a −0 constant; the widened condition is never true on a leaf. It is an equivalent mutant, not an inexact rule. The test passes it, as it must. The always-true condition above is the sub-zero mutant the test does catch. The advisor should confirm this reading before the review.

**C4.2.** `max` commutativity joins the rejected laws; `rejected_pairs()` and `hand_built_pairs()` live in `tests/common/mod.rs`; the fresh-process test now also keys both lists; the pair generator applies `sub-zero` (a rewrite is kept only if the program still type-checks), so the 1,000 pairs differ from the review's. Result: 0 of 1,000 unmerged. The hand-built list has 20 pairs (≥ 20 required).

**Runs.** Kernel cargo suite (`cargo test --release`, `cargo-c41-rebuild.txt`): all pass, rules 7/7 in 213 s, canon 3/3, keys 3/3. Full pytest by `ops/shards.py` at the test commit: 1734 tests, 6 failed, 1702 passed, 1 skipped, 25 xfailed. All six are the worktree, not the code: four need `data/` (absent from a worktree) and two need `bwrap` (absent on gmktec); rerun here with `data` linked and locally, all six pass.

**Item 5 of the final review, 2026-11-08 (tests only; `src/` untouched).**
- (a) The named cases' `c(-0.0)` became `neg(c(0))` (`neg0()`): `dsl.rs` stores constants as `(x + 0.0)`, so a −0 constant parses to +0, while `neg` of +0 evaluates to −0. `the_negative_zero_operand_is_negative_zero` fails on `c(-0.0)` ("nums()[1] is not -0 at evaluation") and passes on `neg0()`. Commutations of two equal operands (`add-comm`, `mul-comm` on `a == b`, `and-comm`, `or-comm` on `p == q`) have no match, since the rewrite is the identity, and are no longer generated (`push_lhs`). The random generator's `c(-0.0)` is left, which keeps `GENERATED_DIGEST`.
- (b) `check_trees` asserts every named tree has a matching position (except the "any right operand" ones), and `random_cases` gives up after `TRIES` = 1000 planted programs per case. Throwaway mutant, `sub-zero`'s pattern changed to `(subx ?x ?z)` and reverted: `signed_zeros_and_undefined_conditions`, `running_sum_recompute_boundaries` ("no matching position") and `every_rule_is_exact` ("no matching position in 1000 planted programs") all fail, in 233 s. Before, only the per-rule `defined > 0` would notice.
- Runs: rules 8/8 in 241 s, canon 3/3, keys 3/3; exit lines in `cargo-c41-rebuild.txt` (appended).
