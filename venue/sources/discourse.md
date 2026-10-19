# Discourse forums (stage 5 discussion source)

Public read-only JSON of each forum's `/posts.json` (the latest 50 posts, newest first), polled
by `ingest/sources_record.py` every 5 minutes. Terms: these are public forum pages served as JSON
to anonymous visitors. We store post ids, topic ids, timestamps and content hashes only, not post
text. Rate limit: none documented for anonymous reads; we make 7 requests per 5 minutes in total.

| Forum | Coin of U | Mapping key |
|---|---|---|
| delvingbitcoin.org | BTC | forum host |
| ethresear.ch | ETH | forum host |
| forum.solana.com | SOL | forum host |
| forums.sui.io | SUI | forum host |
| forum.celestia.org | TIA | forum host |
| governance.aave.com | AAVE | forum host |
| forum.bnbchain.org | BNB | forum host |

Unmapped: kPEPE, WIF, POPCAT, WLD and FTM. There is no reachable public forum for them;
community.worldcoin.org and forum.soniclabs.com did not respond.

Timestamp classes: `created_at` and `updated_at` are server-set by Discourse. Imports and admin
edits can rewrite them; the live reconciliation measures how often.

knownAt rule, fixed 2026-10-19 before any live measurement: a post's existence is known at
`created_at` + 600 s. Its content is known at `updated_at` + 600 s. Deleted posts become
tombstones when they stop appearing on re-polls of their topic.
