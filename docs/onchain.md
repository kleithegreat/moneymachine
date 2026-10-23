# On-chain data: feasibility on this machine (2026-10-23)

Human decision of 2026-10-23: on-chain data is a priority source family. Chain data read from our own node, or
from an official archive, carries no data provider's terms. The access route still has terms of its own: a cloud
account, a requester-pays bucket or an RPC provider. Hard limits and the autonomy rules apply to that route.

## This machine

| | Have | Notes |
|---|---|---|
| CPU | Intel i5-11400, 6 cores, 12 threads | |
| RAM | 15 GB (+15.5 GB zram) | about 10 GB available beside the recorders |
| Fast disk | nvme0n1 500 GB (root, 91 GB free); nvme1n1 500 GB (not mounted here) | |
| Slow disk | sda 2 TB HDD (rotational) | too slow for a node's state database |
| Network | home connection | |

## Options

| Option | Data | Needs | Feasible here | Status |
|---|---|---|---|---|
| **Hyperliquid non-validating node** (`hyperliquid-dex/node`) | fills, trades, every L1 order status, misc events (funding, transfers, liquidations), replica commands | "16 vCPUs, 128 GB RAM, and 500 GB SSD storage"; "Currently only Ubuntu 24.04 is supported"; "around 100 GB of logs per day" | **No**: RAM 15 of 128 GB, 12 of 16 threads, and the log rate fills the free SSD in a day | Blocked on hardware |
| **Hyperliquid official archives** (`s3://hyperliquid-archive`: `l2Book` per hour, `asset_ctxs` daily; `s3://hl-mainnet-node-data`: `node_fills_by_block`, `misc_events_by_block`, `explorer_blocks`) | historical books, asset contexts (funding, open interest, marks), fills, non-trade events | an AWS account, and paying transfer costs: the bucket is requester-pays ("must pay for transfer costs") | Disk: yes, by selecting dates and coins | Blocked: an account in the human's name and money (autonomy rule 2) |
| **Hyperliquid info API** (in use) | live books, funding history, candles, asset contexts as recorded | nothing new | Yes | Running: stage 0's recorder, which becomes the regime diagnostic at 480/min. `metaAndAssetCtxs` could be added to keep marks and open interest point in time |
| **Ethereum via BigQuery public datasets** (`bigquery-public-data.crypto_ethereum`) | blocks, transactions, logs, token transfers, traces | a Google Cloud account; the sandbox gives 1 TB of queries a month without a card | Yes, compute is remote | Blocked: an account in the human's name |
| **Ethereum local node** | full chain, ours, no provider | a full node (e.g. reth or geth) needs about 1.2–1.5 TB of fast SSD and 16 GB+ RAM; an archive node needs about 2.5–3 TB | **No**: 91 GB free on the root SSD; the spare 500 GB NVMe is too small; the HDD is too slow | Blocked on hardware (a 2–4 TB NVMe would unlock a full node) |
| **Polymarket on-chain history** (Polygon: CTF Exchange order-fill events) | every fill, hence market-implied probabilities over time, as a stage 10 baseline | our own Polygon node (multi-TB, blocked like Ethereum), a public RPC (provider terms), BigQuery's Polygon dataset (account), or Polymarket's own APIs (CLOB price history, Gamma markets) | APIs: yes. Own node: no | Human decision: the terms page gives no API terms, trading is blocked in the US, and the terms reportedly bar US persons from the international product (Blockers) |

## What would change this

- **A 2–4 TB NVMe:** an Ethereum full node, and Polygon later.
- **An AWS account with a small transfer budget:** the Hyperliquid archives, selected by date and coin.
- **A Google Cloud account:** the Ethereum and Polygon public datasets on BigQuery.
- **A machine with 128 GB of RAM:** a Hyperliquid node.
