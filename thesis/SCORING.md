# Thesis scoring: input schema and rules

This is the specification for C10.4 (audit/criteria.md, stage 10). An implementation reads one test set and
returns the outputs below. All times are UTC milliseconds. HOUR = 3,600,000, DAY = 86,400,000,
δ = 120,000.

## Input

```json
{
  "account": {"fee": 0.00045,
              "costs": {"<market>": {"buy": {"1000": bps, "10000": bps}, "sell": {"1000": bps, "10000": bps}}}},
  "hourly": {"<market>": [[openTime, open, close | null], ...]},
  "daily": {"<market>": [[openTime, open, close], ...]},
  "funding": {"<market>": [[hour, rate], ...]},
  "now": ms,
  "theses": [{"id": "t1", "session": "s1", "catalyst_id": "c1", "legs": [["<market>", 1 | -1], ...],
              "t_r": ms, "T": ms, "N": dollars, "p": 0.6, "p_ablation": 0.55 | null}]
}
```

- **Bars.** Hourly bars open at multiples of HOUR, and daily bars at multiples of DAY. A market may have missing bars.
- **Funding.** Funding settles every hour, so a market has a row for every hour (a multiple of HOUR) unless that row is missing. A missing row is missing data, never a zero rate. An hourly close may be null: the bar has an opening price but no closing price (a builder market whose next mark is missing). Daily closes are never null.
- **Thesis order.** Theses are listed in registration (commit) order.
- **N.** N is the thesis's notional per leg, set at registration (size-zero theses have a hypothetical N).
- **p_ablation.** p_ablation is the conditional ablation's probability, or null if it is missing.

## Outcome (as registered)

For each leg (market m, sign w):
- **Times.** The entry time e is the first hourly openTime ≥ t_r + δ, and the exit time x is the first hourly openTime ≥ T. Only bars with openTime ≤ now count. If either does not exist, or e ≥ x, the thesis is unresolved (outcome null).
- **Quantity.** q = w · N / open(e).
- **Fills.** Trading quantity k at reference price r:
  - the side is buy if k > 0, else sell;
  - the cell is the market's costs[side]["1000"] if |k| · r ≤ 1000, else ["10000"];
  - the price is r · (1 + bps/10⁴) for a buy and r · (1 − bps/10⁴) for a sell;
  - the fee is |k| · price · fee.
- **Leg contribution.** The entry is a fill of q at open(e), and the exit a fill of −q at open(x). The leg contributes q · (exit price − entry price) − entry fee − exit fee.
- **Funding.** For every hour h with e < h ≤ x, the leg contributes −q · rate · mark(h), where rate is m's funding row for h. If any of these rows is missing, the thesis is unresolved (outcome null). Here mark(t) uses the hourly bars: take the last bar with openTime s ≤ t; it is its close if s + HOUR ≤ t and that close is not null, otherwise its open.
- **Result.** R_net = (sum of the leg contributions) / N, and o = 1 if R_net > 0, else 0.

## Base rate

- **Duration.** D = floor((T − t_r) / DAY + 0.5) days.
- **Anchor.** a = the largest daily openTime ≤ t_r that every leg has. If there is none, the base rate is unavailable.
- **Windows.** For k = 0, 1, 2, …, window k has exit day x_k = a − k · D · DAY and entry day e_k = x_k − D · DAY. It is considered only while e_k ≥ t_r − 1,095 · DAY.
- **Completeness.** A window is complete if every leg has daily bars at e_k and x_k. Incomplete windows are omitted, and the others do not move.
- **Window return.** It is computed as the outcome, with daily opens instead of hourly opens, the same N, fee and cost cells, and the leg's quantity q = w · N / daily open(e_k). For every hour h with e_k < h ≤ x_k, the funding row for h is priced at the open of the daily bar with openTime ≤ h < openTime + DAY. If a funding row or that daily bar is missing, the window is incomplete.
- **Estimate.** Let m be the number of complete windows and x the number with a window R_net > 0. If m ≥ 10, p_ref = (x + 1)/(m + 2); otherwise p_ref is null.

## Scores

Only resolved theses count, and p is the main probability.
- **B.** The mean of (p − o)² over resolved theses, or null if there are none.
- **Base-rate comparison.** Over resolved theses with a non-null p_ref (the pairs): B_pair = the mean of (p − o)², B_ref = the mean of (p_ref − o)², n_pairs, and diff = B_pair − B_ref. skill = 1 − B_pair / B_ref, or null if B_ref = 0 or there are no pairs.
- **Ablation comparison.** The same with p_ablation in place of p_ref.

## Clusters

- **Graph.** Nodes are all theses, resolved or not, including size zero. Two theses are linked if they have:
  - the same session;
  - the same catalyst_id; or
  - a common market among their legs (either direction), where the closed intervals [t_r, T] intersect (touching counts).
- **Clusters.** The clusters are the connected components. Each is named by its earliest thesis in input order, and members are listed in input order.
- **Resolved.** A cluster is resolved if all its members are resolved.

## Output

```json
{"theses": {"t1": {"outcome": {"R_net": x, "o": 0 | 1} | null, "p_ref": x | null, "m": int, "x": int}},
 "scores": {"n_resolved": int, "B": x | null,
            "base_rate": {"n_pairs": int, "B": x | null, "B_ref": x | null, "diff": x | null, "skill": x | null},
            "ablation": {"n_pairs": int, "B": x | null, "B_ref": x | null, "diff": x | null, "skill": x | null}},
 "clusters": [{"name": "t1", "members": ["t1", "t3"], "resolved": true}]}
```
