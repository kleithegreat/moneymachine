# C1.5: GPT's independent fill checker, second implementation (2026-10-26)

`kernel/tests/timing/gpt_checker.py` was written by GPT 6.1 Sol (`openai/gpt-6.1-sol#high`, opencode, edit, bash,
webfetch and external_directory denied) from `docs/whitepaper.tex` and `kernel/INVARIANTS.md` alone, after the case
format moved from `kernel/tests/timing/FORMAT.md` into `INVARIANTS.md` (Fill-check cases). It replaces the first
implementation, which had also been given FORMAT.md. It matched all 2,000 generated labels (1,159 planted violations)
on its first run. The prompt:

> Implement an independent fill checker from whitepaper.tex and INVARIANTS.md alone; you have nothing else and must not ask for any source. INVARIANTS.md's section 'Fill-check cases (mm check-fills)' gives the case format and the verdict rules, and its I2, I3 and I9 rows give the invariants. Write one Python 3 module, standard library only, defining check(case: dict) -> str, which returns the verdict for one decoded case object: 'R_TIMING', 'R_FILL', 'R_PORTFOLIO' or 'ok'. Cover every requirement those rows and that section state, including closeouts (liquidation and delisting), the source bar, unfilled-order and no-roll rules as they apply to a single recorded fill, the cost bucket, exact IEEE price and fee comparison in the stated order, and the stated verdict precedence. Begin the module with a comment saying it was written by GPT 6.1 Sol from whitepaper.tex and INVARIANTS.md alone. Reply with the module's source only, in one python code block; do not write files.
