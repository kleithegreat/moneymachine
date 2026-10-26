# C1.4: disagreements between `mm` and the stage 0 witness, and their root causes

Recovered on 2026-10-26 from the commit messages that resolved them, which are the only record; each was resolved before
the judged run (`c14.txt`).

| Commit | What the commit records |
|---|---|
| b4fab10 (2026-10-19) | the fill-before-decision ordering, fixed in the kernel and the witness |
| aa00973 (2026-10-19) | the witness fills at the bar after the decision, per C0.8's revision of 2026-10-19 |
| 2629bb3 (2026-10-19) | kernel and witness fill only when a later bar marks the fill |
| ddb2c63 (2026-10-19) | the witness takes the current listed-interval rule, W0's DSL arithmetic and the venue's coin order; the dry C1.4 run then passes |
| c5829d8, 57e4de9 (2026-10-22) | on the second fetch, `mm` and the store's `as_of` resolved availability-corrected revisions differently (dry C1.4 failed); resolved by the C0.4 amendment of 2026-10-22 (`audit/criteria.md`), after which the dry run passes |

The judged run of 2026-10-26 (`c14.txt`, after the `post-stage0` merge) passed.
