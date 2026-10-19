# Research notes

## Mechanism obligations

Every strategy must ship with a stated mechanism, and the mechanism must imply tests beyond PnL. These tests are additional empirical checks that can count against a strategy; they are not a second verifier comparable to a proof checker. The obligation has three parts:

  - **Counterparty.** Who is on the other side of the trade, and why are they willing to trade at this price? The counterparty need not be wrong: forced sellers at liquidation, hedgers paying for immediacy, and traders reducing inventory can all be acting rationally.
  - **Conditional predictions.** If the mechanism is real, the effect should vary in specified ways, with stated tolerances. A liquidation-cascade strategy should earn more when positions are crowded near liquidation and less when funding has normalized. A slow-information strategy should decay as the information ages.
  - **Capacity and decay.** Roughly how much size the effect supports, and what would make it disappear.

Conditional predictions are written down before they are tested and logged in the ledger like any other experiment. Ideally they are tested on data not used to find the strategy, since predictions checked on the same sample are not independent of the PnL result. A failed prediction is evidence that the stated explanation is wrong, not proof that the strategy is: it may work for another reason, or the test may lack power. Under the gate, a failed pre-registered prediction removes the candidate from that campaign's finalists; it can be re-proposed with a revised mechanism in a later campaign, evaluated on fresh data.

A working hypothesis of this design is that LLMs are most useful here for proposing economically plausible ideas rather than for blind search. That hypothesis should be tested against simpler generators, such as random or genetic search over the same DSL, using the same gate.

## Research directions for retail edge

The method is not the edge: institutions already run automated alpha research. The directions below are hypotheses about where a small account might compete, not demonstrated sources of return, and each depends on the data actually supporting a point-in-time backtest.

  - **Small capacity.** Some strategies support too little size to interest a large fund, though institutions do not ignore small opportunities uniformly, and costs, infrastructure, and diversification all matter.
  - **Venue structure on Hyperliquid.** Positions and margin for given addresses are far more observable than on centralized venues, which makes crowding, deleveraging, funding dislocations, and copy-trading flows testable in principle. In practice, liquidation prices depend on cross-margin account state, funding paid, and partial-liquidation rules, so they cannot be rebuilt from entry price and leverage alone. Historical archives can also have gaps. Any feature built on liquidation exposure must be reconstructed from account state as it stood at each decision time.
  - **Slow, messy information.** Retail will not win the race to a headline. Governance proposals, token unlock schedules, protocol documentation, and long-tail discussion may be absorbed by the market slowly; LLMs make reading them cheap, though they make it cheap for competitors too.
  - **Catalyst triage.** Agents monitor sources, tag events by affected asset and mechanism, and route them to the relevant strategy family. The triage output is itself a point-in-time data source in the data schema.

In this architecture, observed wallet activity is treated primarily as data rather than as something to copy directly, and it raises two separate problems. Among thousands of visible wallets, many strong records are luck, which deflated statistics can partly correct. Survivorship is a different problem: wallets that blew up, were abandoned, or moved funds may be missing from whatever set looks visible today, and no adjustment to the survivors' Sharpe ratios recovers them. Ranking wallets requires a defined historical universe with explicit inclusion rules, and even then unusual performance can reflect hidden risk exposure rather than skill.
