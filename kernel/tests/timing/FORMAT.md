# Fill-check cases

One JSON object per line:

```
{"id": "c0",
 "taker_fee": 0.00045,
 "cost_bps": {"buy": [c_le_1k, c_gt_1k], "sell": [c_le_1k, c_gt_1k]},
 "bars": [{"open_time": ms, "event": ms, "open": x, "high": x, "low": x, "close": x, "trades": n}, ...],
 "fill": {"why": "fill" | "liquidation" | "delisting", "qty": signed coins (> 0 buys),
          "inputs_known": ms, "decision_price": x, "decided": ms, "submitted": ms, "filled": ms,
          "source_open": ms, "reference": x, "price": x, "fee": x}}
```

All bars belong to the fill's coin, sorted by `open_time`, at most one per `open_time`. `event` is the bar's close time. `cost_bps[side][0]`
applies when |qty| · reference ≤ 1000, `[1]` otherwise. Prices compare exactly, as IEEE
doubles: price must equal `reference * (1.0 + s * bps / 1e4)` computed in that order, and fee
`abs(qty) * price * taker_fee`.

The verdict is the first failing rule: `R_TIMING` (I2), then `R_FILL` (I3), then
`R_PORTFOLIO` (an order of `why = "fill"` whose |qty| · decision_price exceeds $10 000).
Otherwise it is `ok`. Generated cases (`gen.py`) also carry `label` and `kind`, and contain
at most one violation each.
