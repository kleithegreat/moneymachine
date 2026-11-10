"""Dependence units for the thesis track (paper T2; audit/stage10/redesign-build-plan.md).

Part A: how many resolved units each rule yields over time, under session-level market concentration.
  - components: SCORING.md's connected components (same session, same catalyst, or a common market with
    intersecting [t_r, T]); a component resolves when every member has.
  - weeks: the registration week (UTC Monday 00:00); a week resolves when every thesis registered in it has.
Part B: coverage of a 95% interval for the mean paired Brier difference d = (p - o)^2 - (p_abl - o)^2 under
  three variance estimators, and the one-sided power of the week-HAC t test, on a factor model of outcomes with
  overlapping windows and session-shared forecast shocks. Assumptions are stated inline; none is measured.
"""

import sys
from math import ceil

import numpy as np
from scipy.stats import norm, t as student

rng = np.random.default_rng(10)
DAY = 1


def zipf_weights(m, s=1.0):
    w = 1.0 / np.arange(1, m + 1) ** s
    return w / w.sum()


def registrations(days, per_day, pool, h_max, h_min=7, catalyst_reuse=0.3):
    """One main session a day; `per_day` theses on Zipf-chosen markets with uniform horizons in [h_min, h_max] days."""
    w = zipf_weights(pool)
    rows = []
    recent = []
    cid = 0
    for d in range(days):
        n = rng.poisson(per_day) if per_day != int(per_day) else int(per_day)
        for _ in range(n):
            if recent and rng.random() < catalyst_reuse:
                c = recent[rng.integers(len(recent))]
            else:
                cid += 1
                c = cid
            recent = [x for x in recent[-14:]] + [c]
            m = int(rng.choice(pool, p=w))
            h = int(rng.integers(h_min, h_max + 1))
            rows.append((d, d + h, m, c, d))
    return rows


def components(rows):
    n = len(rows)
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def link(i, j):
        parent[find(i)] = find(j)

    by_market, by_catalyst, by_session = {}, {}, {}
    for i, (t_r, T, m, c, s) in enumerate(rows):
        by_market.setdefault(m, []).append(i)
        by_catalyst.setdefault(c, []).append(i)
        by_session.setdefault(s, []).append(i)
    for group in list(by_catalyst.values()) + list(by_session.values()):
        for i in group[1:]:
            link(group[0], i)
    for group in by_market.values():
        for a in range(len(group)):
            for b in range(a + 1, len(group)):
                i, j = group[a], group[b]
                if rows[i][0] <= rows[j][1] and rows[j][0] <= rows[i][1]:
                    link(i, j)
    comps = {}
    for i in range(n):
        comps.setdefault(find(i), []).append(i)
    return list(comps.values())


def resolved_components(rows, now):
    return sum(all(rows[i][1] <= now for i in comp) for comp in components(rows))


def resolved_weeks(rows, now):
    weeks = {}
    for t_r, T, *_ in rows:
        weeks.setdefault(t_r // 7, []).append(T)
    return sum(max(ts) <= now for ts in weeks.values())


def part_a():
    print("A. resolved units after 91 and 365 days (components | weeks); one session/day")
    for pool, per_day, h_max in [(278, 1.4, 60), (60, 1.4, 60), (60, 2, 60), (30, 2, 60), (60, 2, 28), (60, 4, 28)]:
        rc = []
        for _ in range(20):
            rows = registrations(365, per_day, pool, h_max)
            rc.append((resolved_components(rows, 91), resolved_components(rows, 365),
                       resolved_weeks(rows, 91), resolved_weeks(rows, 365), len(rows)))
        rc = np.array(rc).mean(0)
        print(f"  pool {pool:>3} markets, {per_day} theses/day, horizon <= {h_max:>2} d: "
              f"components {rc[0]:5.1f} | {rc[1]:6.1f}   weeks {rc[2]:4.1f} | {rc[3]:4.1f}   (theses {rc[4]:.0f})")


def outcomes_and_forecasts(rows, pool, gamma, lam=0.35, miscal=0.15, session_sd=0.08, noise_sd=0.05, builder_share=0.4):
    """Daily market returns: beta_m * common factor + idiosyncratic. The achievable signal z_i is the standardized window
    return mixed with noise (lam: information share); q_i = P(o_i = 1 | z_i). The ablation reports p_abl = q distorted
    by a per-thesis miscalibration; the main arm moves a fraction gamma of the way back to q and adds a shift shared by
    the session's theses (the same reading) and its own noise."""
    days = max(T for _, T, *_ in rows) + 1
    beta = np.where(np.arange(pool) < pool * (1 - builder_share), 0.8, 0.3)
    f = rng.standard_normal(days)
    eps = rng.standard_normal((pool, days)) * np.sqrt(1 - beta[:, None] ** 2)
    ret = beta[:, None] * f[None, :] + eps
    r = np.array([ret[m, t_r:T].sum() / np.sqrt(T - t_r) for t_r, T, m, *_ in rows])
    u = rng.standard_normal(len(rows))
    z = lam * r + np.sqrt(1 - lam ** 2) * u
    q = norm.cdf(lam * z / np.sqrt(1 - lam ** 2))
    o = (r > 0).astype(float)
    p_abl = np.clip(q + rng.normal(0, miscal, len(rows)), 0.01, 0.99)
    sessions = np.array([s for *_, s in rows])
    shift = rng.normal(0, session_sd, sessions.max() + 1)[sessions]
    p = np.clip(p_abl + gamma * (q - p_abl) + shift + rng.normal(0, noise_sd, len(rows)), 0.01, 0.99)
    return (p - o) ** 2 - (p_abl - o) ** 2


def week_hac(d, weeks, lag):
    """Mean of d and its standard error from week sums with a Bartlett kernel over `lag` weeks (Driscoll-Kraay form)."""
    W = weeks.max() + 1
    n = len(d)
    mean = d.mean()
    s = np.bincount(weeks, weights=d - mean, minlength=W)
    var = (s ** 2).sum()
    for ell in range(1, lag + 1):
        var += 2 * (1 - ell / (lag + 1)) * (s[ell:] * s[:-ell]).sum()
    return mean, np.sqrt(max(var, 0)) / n, W


def part_b(reps=1000):
    print("\nB. the paired difference d = (p-o)^2 - (p_abl-o)^2; pool 60, Zipf, factor model; horizon 7..28 d unless stated")
    print("   coverage of a nominal 95% interval for E[d]: iid | week-cluster | week-HAC (Bartlett, lag ceil(h_max/7));")
    print("   power: one-sided 5% week-cluster t test of E[d] < 0 (t quantile on W - 1 df)")
    pool = 60
    scenarios = [("null: reading adds noise only", 0.0, 0.15, 0.08), ("small: a quarter of the miscalibration", 0.25, 0.15, 0.08),
                 ("medium: half of it, less session shift", 0.5, 0.15, 0.05), ("large: three quarters of a larger one", 0.75, 0.2, 0.05)]
    grid = [(13, 2, 28), (13, 4, 28), (26, 2, 28), (26, 4, 28), (26, 4, 60), (39, 4, 28), (52, 4, 28)]
    for name, gamma, miscal, session_sd in scenarios:
        truth = {}
        for h_max in (28, 60):
            big = [outcomes_and_forecasts(registrations(7 * 52, 2, pool, h_max), pool, gamma, miscal=miscal, session_sd=session_sd)
                   for _ in range(40)]
            truth[h_max] = np.concatenate(big).mean()
        print(f"  {name}: E[d] = {truth[28]:+.4f} (horizon <= 60 d: {truth[60]:+.4f})")
        for weeks_n, per_day, h_max in grid:
            lag = ceil(h_max / 7)
            cover = np.zeros(3)
            reject = 0
            for _ in range(reps):
                rows = registrations(7 * weeks_n, per_day, pool, h_max)
                d = outcomes_and_forecasts(rows, pool, gamma, miscal=miscal, session_sd=session_sd)
                weeks = np.array([t_r // 7 for t_r, *_ in rows])
                n = len(d)
                mean = d.mean()
                se_iid = d.std(ddof=1) / np.sqrt(n)
                s = np.bincount(weeks, weights=d - mean, minlength=weeks_n)
                se_cl = np.sqrt((s ** 2).sum()) / n
                _, se_hac, W = week_hac(d, weeks, lag)
                qt = student.ppf(0.975, W - 1)
                for k, se in enumerate((se_iid, se_cl, se_hac)):
                    cover[k] += abs(mean - truth[h_max]) <= qt * se
                reject += (mean / se_cl) < student.ppf(0.05, W - 1)
            cover /= reps
            print(f"    {weeks_n:2d} weeks x {per_day}/day, horizon <= {h_max}: coverage iid {cover[0]:.3f}  cluster {cover[1]:.3f}  "
                  f"HAC {cover[2]:.3f}   power {reject / reps:.3f}")


if __name__ == "__main__":
    part_a()
    part_b(int(sys.argv[1]) if len(sys.argv) > 1 else 1000)
