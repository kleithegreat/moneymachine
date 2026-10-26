# C1.2: evasions found, their fixes, and the cases kept

| Case | Evasion | Root cause and fix |
|---|---|---|
| `t22_convert_overflow_shares_node` | two `convert` nodes whose factors both overflow to 0 type-checked as one, so an `add` of different units passed | the checker interned a conversion node by its factor alone; 5f2b538 (2026-10-20) keys it by its target unit as well, in `mm` and the Lean model |

No other case in either red-team round evaded the checker: round 2's 22 (`redteam2-gpt.json`) all got their expected codes on the first run.
