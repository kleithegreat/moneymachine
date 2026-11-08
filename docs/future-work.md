# Future work

Ideas for after the pilot, none approved, scheduled or tested. The paper (`docs/whitepaper.tex`) is the intent and its roadmap the plan; an idea here enters it only through its own stage, criteria and source certificates. Two constraints apply to all: the binding constraint is independent observations, so breadth raises the bar a result must clear; and every judged pilot result comes from one frozen kernel, so none of this starts before the pilot answers whether the search controls false discoveries.

## Directions (the human, 2026-11-01 to 2026-11-06)

- **An automated quant shop**: the kernel one tool among many, agents used the way firms use people; later "any data, any market". The source declarations already generalize to any data; any market needs an execution model per venue (fees, fills, latency, limits), where backtests usually fail.
- **Forecasting and fundamentals**: already the thesis track (stage 10); the most natural extension, needing no speed.
- **Harnesses for non-Anthropic models** (pi).
- **Observability**: a price-free operations dashboard is cheap; one showing forward-window prices breaks the holdout rule.
- **Agent memory across campaigns**: a research question, its reuse counted in N (`audit/decisions.md`, 2026-11-02).
- **A DSL designed for agents** (the human, 2026-11-07): the DSL's frozen job in the pilot is safety (causal, typed, no host code); how well agents search with it is unmeasured. v3's six campaigns: 2 type errors in 231 checks; 11 of 208 evaluations named an input N2 lacks; holding a position through an undefined weight (documented in `kernel/DSL.md`) was rediscovered as a "turnover workaround". First a literature review (languages agents learn without pretraining, such as Bend2; where expressivity should stop for safety; what "optimal" means here), then a metric and a comparison of surface syntax, primitives and docs over one fixed kernel under fresh campaign ids. Lowers search power if poor, never raises false discoveries. The two literature reviews, checked (`audit/reviews/2026-11-08-sonnet-research-dsl.md`): change the surface agents see, never the kernel's semantics; a measurable "optimal" (planted-edge recovery at a fixed budget, null promotions unchanged) and a sized comparison there. First, `kernel/DSL.md` advertises inputs N2 lacks, the likely cause of the 11 unknown-input evaluations.
- **Data purchases** (Norgate, Massive, Databento's Core Indices): none, indefinitely (the human, 2026-11-02).

## Crypto-native and on-chain research ideas (2026-11-06)

From the advisor and GPT independently; GPT's ranking, with the advisor's overlapping ideas folded in. "Forward" means testable only on data recorded from now on.

1. **Governance changes that move token-holder cash flows** (buybacks, fee switches, issuance cuts), counted when implemented on chain, not when a vote passes. Forward thesis track: an LLM's reading of significance can't be backtested. Snapshot is recorded (AAVE only); stage 7 builds governance event feeds. Kill: no skill over the no-reading ablation and a simple implementation-event rule.
2. **Funding carry on large, persistent dislocations, hedged**, not "short the highest funding". Backtestable on recorded Hyperliquid funding; needs a spot hedge leg the engine lacks, and the hedge venue's own permission. Kill: subsequent carry doesn't cover all-in costs and basis moves.
3. **Verified treasury or vesting sales**, not unlock calendars: contract-defined releases that become observed selling. Backtestable for contract-defined events, including dead tokens. Kill: confirmed sales add nothing beyond the public schedule, or borrow costs eat the decline.
4. **Lending-market migration** after cap, rate-model or incentive changes: realized withdrawable yield within comparable risk. Needs lending accounting in the engine.
5. **Liquid-staking discounts against redemption-queue costs**: history only since 2023's withdrawals, few stress episodes.
6. **Recovery after forced deleveraging ends**, not front-running liquidations. Hyperliquid's positions are public, but no account-state history is certified: forward.
7. **Liquidity-incentive expirations**: farmers withdraw and sell rewards over days.
8. **Organic protocol revenue after subsidies and dilution**, where the token has an enforceable accrual channel.
9. **Cross-chain capital migration** with an explicit economic link to the traded asset.
10. **Crypto-event forecasts scored against Polymarket** on the thesis track (Polymarket recorded, read-only).

Common catch: most need new feeds (on-chain contract state, each needing a certificate; BigQuery's crypto tables are not certified) and engine extensions (spot hedge, lending, redemption queues); crypto histories run two to seven years, below stage 8's fifteen, so they need a reviewed scope revision or a separate campaign. The two that fit the machinery already built are 1 and 2.

## Rejected, and why

- **Sportsbook arbitrage**: books limit winners and their terms generally forbid automation. Prediction-market exchanges with official APIs are a separate case.
- **Airdrop farming at scale**: many wallets posing as distinct users is Sybil deception against the protocol's terms.
- **Token sniping, MEV, sandwiching, mempool front-running**: latency races against faster bots and adversarial deployers; backtests can't model being front-run or honeypots; an agent holding keys against hostile contracts.
- **Copying top wallets**: selection on survivors, hidden hedges.
- **"Stablecoins minted, so buy crypto"; buying every depeg; farming the highest APY**: weak causal story, or short records hiding catastrophic tails.
- **LLM sentiment backtests over historical news or governance**: the model may know the outcomes; interpretation belongs forward.
- **Mining indicators across hundreds of tokens**: data snooping (Sullivan, Timmermann and White); correlated tokens are not fresh evidence.
- **HIP-3 venue effects judged on the underlying's long history**: that history never saw the venue's mechanism.
- **CEX-DEX arbitrage, social-platform meme prediction**: the weakest of the 2026-11-01 directions.
