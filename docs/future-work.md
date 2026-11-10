# Future work

Ideas outside the program (`docs/whitepaper.tex`, Roadmap), none approved, scheduled or tested. An idea enters only as a study with its own criteria and source certificates, and only if its information rate beats what is running: per-observation effect squared times independent observations a month (paper, section 10). For any strategy a 2026 model proposes, history before that model's cutoff cannot judge it, so "backtestable" below means "has data", not "can be confirmed".

## Directions (the human, 2026-10-23 to 2026-11-07)

- **A research arm with an earlier knowledge cutoff** (2026-10-23): parked with a condition. It moves the confirmable Sharpe from about 5 to about 2 and reads only one way (`audit/program/architecture.md`, sections 3 B and 4).
- **An automated quant shop**: the kernel one tool among many; later "any data, any market". The source declarations already generalize to any data; any market needs an execution model per venue, where backtests usually fail.
- **Harnesses for non-Anthropic models** (pi): also what an earlier-cutoff arm on another provider's model would need.
- **Observability**: a price-free operations dashboard is cheap; one showing unread post-cutoff prices spends a holdout.
- **Agent memory across campaigns**: does it raise discovery without raising false discoveries? Measurable as a second arm of the positive control once that study has reported. Its reuse is counted in N (`audit/decisions.md`, 2026-11-02).
- **A DSL designed for agents** (2026-11-07): the pilot DSL's job is safety; how well agents search with it is unmeasured. The metric is the positive control's discovery rate at a fixed budget, with null promotions unchanged; it is worth running if that study accepts 0.2. Change the surface agents see, never the kernel's semantics (`audit/reviews/2026-11-08-sonnet-research-dsl.md`). Known now: `kernel/DSL.md` advertises inputs N2 lacks, and 11 of 208 evaluations in C4.5 v3 named one.
- **Data purchases** (Norgate, Massive, Databento's Core Indices): none, indefinitely (the human, 2026-11-02).
- **A second event venue**: Kalshi, which a United States resident may trade on (to verify), needs its own certificate.

## Crypto-native and on-chain ideas (the advisor and GPT, 2026-11-06)

Each needs a new feed with its certificate, and most need engine extensions (a spot hedge, lending, redemption queues). Under the wall each can be tested only forward: as theses on event contracts where a market quotes the event, otherwise on the parked perp instance.

1. Governance changes that move token-holder cash flows (buybacks, fee switches, issuance cuts), counted when implemented on chain.
2. Funding carry on large, persistent dislocations, hedged.
3. Verified treasury or vesting sales, not unlock calendars.
4. Lending-market migration after cap, rate-model or incentive changes.
5. Liquid-staking discounts against redemption-queue costs.
6. Recovery after forced deleveraging ends, not front-running liquidations.
7. Liquidity-incentive expirations.
8. Organic protocol revenue after subsidies and dilution, where the token has an enforceable accrual channel.
9. Cross-chain capital migration with an explicit economic link to the traded asset.

## Rejected, and why

- **Forecasting already-resolved events with date-restricted reading**: retrieval leaks, and leakage only flatters the forecaster. At most a futility screen (`audit/program/architecture.md`, section 3 G).
- **Sportsbook arbitrage**: books limit winners and their terms generally forbid automation. Event exchanges with official APIs are a separate case, and the thesis track's venue.
- **Airdrop farming at scale**: many wallets posing as distinct users is Sybil deception against the protocol's terms.
- **Token sniping, MEV, sandwiching, mempool front-running**: latency races against faster bots and adversarial deployers; an agent holding keys against hostile contracts.
- **Copying top wallets**: selection on survivors, hidden hedges.
- **"Stablecoins minted, so buy crypto"; buying every depeg; farming the highest APY**: weak causal story, or short records hiding catastrophic tails.
- **LLM sentiment backtests over historical news or governance**: the model may know the outcomes.
- **Mining indicators across hundreds of tokens**: data snooping (Sullivan, Timmermann and White); correlated tokens are not fresh evidence.
- **HIP-3 venue effects judged on the underlying's long history**: that history never saw the venue's mechanism.
- **CEX-DEX arbitrage, social-platform meme prediction**: the weakest of the 2026-11-01 directions.
