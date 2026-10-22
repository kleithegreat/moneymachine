# Discourse forums (stage 5 discussion source)

Public read-only JSON of each forum's `/posts.json` (the latest 50 posts, newest first), polled
by `ingest/sources_record.py` every 5 minutes. Terms: these are public forum pages served as JSON
to anonymous visitors. We store post ids, topic ids, timestamps and content hashes only, not post
text. Rate limit: none documented for anonymous reads; we make 7 requests per 5 minutes in total.

| Forum | Coin of U | Mapping key | C5.1 precision |
|---|---|---|---|
| delvingbitcoin.org | BTC | forum host | 0.94 |
| forum.solana.com | SOL | forum host | 0.92 |
| forums.sui.io | SUI | forum host | 0.84 |
| forum.celestia.org | TIA | forum host | 0.92 |
| governance.aave.com | AAVE | forum host | 0.88 |

A forum maps to a coin only if the blind-labeled sample (`audit/stage5/c51-discourse.json`) puts its
precision at 0.8 or more; fixed 2026-10-19, before any return on the new inputs. ethresear.ch
(ETH, 0.66) and forum.bnbchain.org (BNB, 0.58) fall below it and are unmapped (mapping version 2).
They are still recorded and backfilled, since C5.3 pools availability over everything the source
publishes. Also unmapped: kPEPE, WIF, POPCAT, WLD and FTM. There is no reachable public forum for
them; community.worldcoin.org and forum.soniclabs.com did not respond.

Timestamp classes: `created_at` and `updated_at` are server-set by Discourse. Imports and admin
edits can rewrite them; the live reconciliation measures how often.

knownAt rule, fixed 2026-10-19 before any live measurement: a post's existence is known at
`created_at` + 600 s, and its content at `updated_at` + 600 s. C5.3 failed as written (a −4.9 s clock reading,
and realized poll gaps). Under the stage 5 amendment of 2026-10-22, the claimed times are therefore never
admitted. Discourse is prospective only, and a post is known 60 s after its earliest observation
(`derived.md`). The claimed-time rule is still measured and reported. Raw revisions are known when fetched,
and a post the backfill no longer lists becomes a tombstone.
