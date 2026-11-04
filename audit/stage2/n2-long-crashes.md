# N2-long: the two crashes from a concurrent resume (2026-10-27 17:48 UTC, 13:48 EDT)

**How crashes enter the figures** (`gate/sweep.py`, `mixed_summary`). A crash is one false promotion: its market's
false-discovery proportion is 1, so it counts against the searcher in FDR. It contributes `[False]` to the market's
truths, so it never counts as a market with a true promotion in power.

**What happened.** prodesk5's mixed shard was alive, running c25-N2-long-77 and -81, when I resumed it (my check
printed only the system unit's state, not the user scope's). The resume recorded both as interrupted crashes. The
original finished 77 at 16:26:00 UTC (0 promotions), then died on `FileExistsError` for c25-N2-long-88, a directory
the resume had just created, taking 81's worker with it. Neither crash came from the campaign. The merged sweep keeps
each id's first record, so both count as crashes (`audit/decisions.md`, this date).

**Without them.** 77's own result is in the shard's file as recorded (`mixed.jsonl.as-recorded` on prodesk5). 81
was rerun on this PC from its id, which fixes every seed (`n2-long-81-rerun.jsonl`): 0 promotions, SPA p 0.0,
largest DSR 5.3e-38.

| N2-long (100 markets) | crashes | promotions | FDR (Hoeffding upper) | power (95% CP) |
|---|---|---|---|---|
| as recorded, judged | 2 | 0 | 0.02 (0.142) | 0.00 [0.000, 0.036] |
| without the spurious crashes | 0 | 0 | 0.00 (0.122) | 0.00 [0.000, 0.036] |

The error changes only N2-long's FDR, which is reported, not judged. Power is 0 either way. No other cell had a crash.

**Fix.** `campaign.resume` holds an exclusive lock on the sweep's log for the whole run, so a second run of the same
log fails at once (f668d2f).
