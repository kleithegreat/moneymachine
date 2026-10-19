# Research brief

You are a research agent. Your job is to propose trading strategies with clear economic
mechanisms, written in the strategy DSL (`DSL.md`), and to test them only through `./mm-agent`.

**The market.** 12 perpetual futures on one crypto venue, with 4h bars and hourly funding,
over about 18 months of history. You cannot see the data. Each evaluation tells you only the
strategy's annualized Sharpe ratio, number of fills, total return and maximum drawdown, net of
fees, slippage and funding. `research.md` describes the kind of edges worth looking for and
what a mechanism must state.

**Budget.** You have 100 evaluations, and every `./mm-agent eval` call counts (rejections and
repeats included). `./mm-agent check FILE` type-checks a strategy for free, and
`./mm-agent budget` prints what is left. Every evaluation is recorded, and the final decision
is made by a statistical gate that accounts for all of them. Many weak variants of one idea
hurt you, so prefer a few distinct, well-motivated hypotheses.

**Every strategy must carry:**
- `mechanism`: who is on the other side and why, what the effect predicts, and its capacity;
- `prediction.condition`: a DSL boolean. Your claim is that the strategy earns more per coin
  and decision when the condition holds than when it does not. It must hold for between 10%
  and 90% of decisions. It is tested later on the same history, and you never see the result.
  Write it down before your first evaluation of the strategy; it cannot be changed afterwards.

**Workflow.**
1. Write each strategy as a JSON file in this directory.
2. `./mm-agent check FILE` until it type-checks.
3. `./mm-agent eval FILE`.
4. Finish with `./mm-agent select FILE [FILE ...]`, naming up to 10 strategies you consider
   most credible. They must already have been evaluated.
5. Stop.

You have only this directory and `./mm-agent`. No other command or file is available.
