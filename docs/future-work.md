# Future work

Ideas outside the program (`docs/whitepaper.tex`, "Two positive controls"), none approved, scheduled or tested. An idea enters only as a study with its own criteria and source certificates, and only if it beats what is running on the wall's arithmetic: independent observations per unit of calendar time (paper, "The confirmation wall"). For any strategy a 2026 model proposes, history before that model's cutoff cannot judge it, so "backtestable" below means "has data", not "can be confirmed".

## Directions (the human, 2026-10-23 to 2026-11-07)

- **A research arm with an earlier knowledge cutoff** (2026-10-23; active design [`audit/program/briefs/5-earlier-cutoff.md`](../audit/program/briefs/5-earlier-cutoff.md)): using models with a verified cutoff <= 2024-06 plus >= 3-month margin unlocks >= 2 years of untouched post-cutoff data, moving the exact confirmer's 80%-power Sharpe benchmark from ~5–27.6 down to ~2 with zero calendar wait; reads only one way (paper, "How the wall moves").
- **An automated quant shop**: the kernel one tool among many; later "any data, any market". The source declarations already generalize to any data; any market needs an execution model per venue, where backtests usually fail.
- **Harnesses for non-Anthropic models**: needed for the earlier-cutoff arm (`audit/program/briefs/5-earlier-cutoff.md`), sketched in OCaml using pinned `libcurl` + `bubblewrap` without new Python.
- **Observability**: a price-free operations dashboard is cheap; one showing unread post-cutoff prices spends a holdout.
- **Agent memory across campaigns**: does it raise discovery without raising false discoveries? Measurable as a second arm of the positive control; study 1 has reported. Its reuse is counted in N (`audit/decisions.md`, 2026-11-02).
- **Data purchases** (Norgate, Massive, Databento's Core Indices): none, indefinitely (the human, 2026-11-02).
- **An event-contract venue**: none is certified. Kalshi's and Polymarket US's terms permit trading use only without written consent (`audit/decisions.md`, 2026-11-11). A reading-agent study reopens on a certificate and a measured count of at least 33 near-independent bets a week (paper, "How the wall moves").
- **Study 1's second cell (unhinted plant) and a DSL designed for agents** (reopened 2026-11-24; [`audit/program/briefs/6-unhinted-search-dsl.md`](../audit/program/briefs/6-unhinted-search-dsl.md)): Study 1 crossed its upper boundary with a brief naming funding dislocations and a strategy guide opening with a line-10 `fade-extreme-funding` example, yet still failed on 24 of 42 completed markets while stopping early at median 9.5 of 100 evaluations (`audit/control-1/`), and `DSL.md` advertised inputs missing from N2 (`forum_posts`, `gov_proposals`, 11 of 208 evaluations in C4.5 v3). Reopened via (a) a zero-cost offline diagnostic of Study 1's 42 kept sessions and (b) Study 1 Cell 2 on a plant not named in the brief or `DSL.md`, paired with an agent-facing DSL surface A/B keeping identical kernel semantics (`audit/reviews/2026-11-08-sonnet-research-dsl.md`).
- **The paired reading design** (an agent with filings against the same agent without): fair, and it needs 859 to 3,437 discordant forecasts (paper, "What stays closed, and what would reopen it").

## Crypto-native and on-chain ideas (the advisor and GPT, 2026-11-06)

Each needs a new feed with its certificate, and most need engine extensions (a spot hedge, lending, redemption queues). Under the wall each is a frozen rule, confirmable forward only at a Sharpe near 2 within two years (paper, "How the wall moves").

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

- **Forecasting already-resolved events with date-restricted reading**: retrieval leaks, and leakage only flatters the forecaster. At most a futility screen (paper, "The knowledge cutoff bounds the judged span").
- **Sportsbook arbitrage**: books limit winners and their terms generally forbid automation. Event exchanges with official APIs are a separate case.
- **Airdrop farming at scale**: many wallets posing as distinct users is Sybil deception against the protocol's terms.
- **Token sniping, MEV, sandwiching, mempool front-running**: latency races against faster bots and adversarial deployers; an agent holding keys against hostile contracts.
- **Copying top wallets**: selection on survivors, hidden hedges.
- **"Stablecoins minted, so buy crypto"; buying every depeg; farming the highest APY**: weak causal story, or short records hiding catastrophic tails.
- **LLM sentiment backtests over historical news or governance**: the model may know the outcomes.
- **Mining indicators across hundreds of tokens**: data snooping (Sullivan, Timmermann and White); correlated tokens are not fresh evidence.
- **HIP-3 venue effects judged on the underlying's long history**: that history never saw the venue's mechanism.
- **CEX-DEX arbitrage, social-platform meme prediction**: the weakest of the 2026-11-01 directions.
