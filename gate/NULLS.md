# Null and planted market models (stage 2)

Synthetic markets use the kernel's store format (`gate/synth.py`): 12 coins `S0..S11`, W's
timeline (`policy.json`), and every bar with `trades = 100`. There are no delistings. The fee is
the production taker fee, and every coin gets, per cost cell, the median over U of the C0.7
cell. Times are those of the stage 0 store: bars at k · 4h, funding at every hour, both
knownAt = eventTime + δ.

## Kernel accounting this must match

Let a coin's 4h bar run from b to b + 4h. Write o = open, c = close, and f₁..f₄ for the
funding rates settled at b + 1h, ..., b + 4h. Per `kernel/mm/src/sim.rs`:
- funding at hour h is paid on the position held at h, priced at the open of the 4h bar
  containing h. So f₁..f₃ are priced at o, and f₄ at the next bar's open, which the generator
  sets equal to c;
- settlement at an instant precedes a fill at that instant. Fills happen only at bar opens, so
  the position paying f₁..f₄ is the one held through the bar;
- a long of q coins held through the bar gains q(c − o) − q·o(f₁ + f₂ + f₃) − q·c·f₄ before
  costs; a short is the same with q < 0.

## No edge

The generator sets c = o · (1 + f₁ + f₂ + f₃ + ε) / (1 − f₄), with the realized rates. The
bar's gross PnL is then exactly q · o · ε. Requirements:
- E[ε | F_o] = 0, where F_o is everything observable at b for every coin and every lag:
  bars closed by b, funding settled by b − 1h, premiums;
- ε is generated from F_o-measurable state plus fresh symmetric noise;
- funding, premium, wicks and volume for bar b are drawn independently of ε given that state.

Every position the kernel takes over the bar is F_o-measurable. It was decided at
b − 4h + δ from data known then, and sized with equity, the decision price, the cap and
rounding. Its expected gross PnL is therefore E[q · o · ε] = E[q · o · E[ε | F_o]] = 0.

Liquidation (`sim.rs`) runs after the hour-(b + 4h) settlement and closes at the adverse extreme
instead of c. For a long, low ≤ c, and for a short, high ≥ c, so a liquidated position's PnL is
the unliquidated PnL plus q · (low − c) ≤ 0 or q · (high − c) ≤ 0. Liquidation never adds
expected PnL.

Fees and the cost model are paid on every fill. So every DSL strategy has expected net PnL ≤ 0,
with equality only if it never fills.

Positivity: |ε| ≤ 0.5 and |f| ≤ 0.04 give c / o ≥ (1 − 0.12 − 0.5) / 1.04 > 0.

## Common pieces

- **ε:** ε = clip(σ_t · x, −0.5, 0.5), where x has a symmetric conditional distribution
  with mean 0. Clipping symmetrically keeps it symmetric, so E[ε | F_o] = 0 still holds. When
  σ_t · |x| > 0.5, the GARCH recursions below use the clipped ε.
- **Wicks:** high = max(o, c) · (1 + |u₁|), low = min(o, c) · (1 − |u₂|), with u₁, u₂ ~
  N(0, (σ_t / 2)²) independent of everything else.
- **Volume:** lognormal with log-mean 10 and log-sd 0.5, i.i.d.
- **Funding and premium:** a stationary block bootstrap (geometric blocks, mean 168 h) of the
  real hourly funding and premium of U over the search part of the stage 0 store. Blocks start at
  the same time for every coin, so cross-coin structure is kept, and synthetic coin S_i takes U's
  i-th coin. The short-history coin's slot (FTM) draws its blocks independently from the other
  coins' series. Real funding sits exactly at the 1.25e-5 interest floor about half the time,
  with fat-tailed, skewed excursions, which no simple parametric model reproduces. Funding is
  exogenous to ε here, so resampling it keeps every no-edge property.
- **Seeds:** numpy `default_rng(seed)`, with the seed taken from the first 8 bytes of
  SHA-256(market id). Draws are made in a fixed order: per bar, then per coin.

## N1 (smoke test)

x ~ N(0, 1) truncated at ±8, with σ_t = 0.02. Funding and premium are 0.

## N2

GARCH(1,1) per coin i: σ²_{i,t} = ω_i + α_i ε²_{i,t−1} + β_i σ²_{i,t−1}, with σ²_{i,0} =
ω_i / (1 − α_i − β_i), and σ capped at 0.0625. Innovations come from a common factor:
x_i = λ z_m + √(1 − λ²) z_i, where z_m and the z_i are i.i.d. standardized Student-t with
ν = 5, each truncated at ±8. Funding and premium are bootstrapped as above.

Fitting uses the search part of the stage 0 store only. Synthetic coin S_i takes the
parameters of U's i-th coin, in U order:
- (α_i, β_i): `arch.arch_model(100 · r, mean="Zero", vol="GARCH", dist="t")` on
  r = c / o − 1 − (f₁ + f₂ + f₃) − f₄ c / o;
- ω_i by variance targeting, ω_i = s_i² (1 − α_i − β_i), with s_i² the sample variance of r_i.
  Fat-tailed near-integrated fits otherwise overstate unconditional volatility (BTC: 2.0% vs
  0.99% per 4h);
- λ: √ of the mean pairwise correlation of the standardized residuals, floored at 0.

## N3

A hidden two-state Markov chain s_t ∈ {L, H} with transition matrix P, shared by all coins.
- σ_{i,t} = σ̄_i · m_{s_t}.
- x_i = √ρ_{s_t} z_m + √(1 − ρ_{s_t}) z_i + J_i, with z standardized Student-t (ν = 5)
  truncated at ±8.
- Jumps: J_i = B_i · K_i / σ_{i,t}, where B_i ~ Bernoulli(p_j) and K_i ~ Laplace(0, k_j)
  truncated at ±0.2. The jump has scale k_j in ε units and is symmetric.

ε is clipped as in the common pieces. Funding and premium are bootstrapped as above.

Fitting uses the search part only:
- σ̄_i: the sample sd of r_i;
- (m_L, m_H, P): `statsmodels` `MarkovRegression(k_regimes=2, trend="n", switching_variance=True)`
  on the equal-weight mean r, with m = the square root of the regime variance divided by the
  sample variance;
- ρ_L, ρ_H: the mean pairwise correlation of r within each smoothed regime (probability > 0.5);
- p_j: the fraction of |r_i / σ̄_i| > 5;
- k_j: the mean of |r_i| − 5 σ̄_i over those events.

## Planted signal (mixed markets)

On the planted coins, x gets an added mean: ε = clip(σ_t · x + β · g_t, −0.5, 0.5). Here
g_t = −clip((f_{b−4h} − 1.25e-5) / 1e-4, −1, 1) is driven by how far the funding settled at the
previous 4h boundary, which is known at that boundary's decision tick, sits from the interest
floor. The oracle is
`gate/strategies/oracle.json`: weight = −clip((funding − 1.25e-5) / 1e-4, −1, 1) · 0.1. The DSL has no coin
identity, so the oracle trades all 12 coins and earns its edge on the planted ones. β is
calibrated so that the oracle's annualized net Sharpe through the kernel is s, on ≥ 200
simulated years.

Clipping a non-centered ε biases its mean toward 0 by at most P(|σx + βg| > 0.5) · 0.5. That
is negligible at these σ and is absorbed by calibrating β through the kernel.

A coin of U with fewer than 1,000 traded bars in the search part (FTM, delisted 2025-01)
takes the median over the other coins of every per-coin parameter.

Parameters are written to `gate/nulls.json` with their sha256 before the first campaign, and
never changed afterwards. A change means new campaign ids, logged.

## C2.1 test units

The probes' PnL unit is the per-step gross return (change in equity plus that step's fees and
slippage, over the previous equity; `gross_return_mean` in `mm eval`'s summary). Its conditional
mean is exactly zero under every null. Dollar PnL of a compounding strategy also has mean zero,
but it is so right-skewed across markets that a z-test on it is invalid (a 10-year N2 trial with
0.96× buy-and-hold had z = −10.6 on dollars, with the kernel's dollar PnL equal to Σ q·o·ε to
1e-10). The regression's F-test uses HC3-robust covariance, since ε is heteroskedastic by design.
