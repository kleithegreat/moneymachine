# Forecast

`task.json` in this directory describes one market exposure, its entry, its horizon and the outcome to
forecast. Give your probability that the outcome happens.

Your only tool is `./thesis-agent` (use it through Bash):

- `./thesis-agent prices MARKET`: a market's completed daily bars, as [openTime ms, open, close], up to the
  forecast time.
- `./thesis-agent forecast P`: record your probability P, between 0.01 and 0.99. You can do this once.

You cannot read any other sources. Use your own knowledge and the price history. Record your forecast
with `forecast` before you finish.
