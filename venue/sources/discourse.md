# Discourse forums (stage 5 discussion source)

Public read-only JSON of each forum's `/posts.json` (the latest 50 posts, newest first), polled
by `ingest/sources_record.py` every 5 minutes. We store post ids, topic ids, timestamps and
content hashes only, not post text.

A forum is fetched only if its own terms permit our automated use (Terms, below). Mapping
version 3 has one forum:

| Forum | Coin of U | Mapping key | C5.1 precision |
|---|---|---|---|
| delvingbitcoin.org | BTC | forum host | 0.94 |

Forums whose terms do not permit automated access are never fetched, and what was fetched from
them before this was checked is deleted (human decision 2026-10-22; `audit/stage5/purge-20261022.json`).
That covers forum.solana.com, forums.sui.io, governance.aave.com and forum.bnbchain.org (Discourse's standard
terms forbid it), forum.celestia.org (its terms forbid bots), and ethresear.ch (its terms are silent, which is
not permission). Other coins of U have no reachable public forum.

Rate limit: Discourse's default per-IP limit is 200 requests per minute and 50 per 10 seconds
([global rate limits](https://meta.discourse.org/t/global-rate-limits-and-throttling-in-discourse/78612),
retrieved 2026-10-22). We make 1 request per 5 minutes per forum, and the backfill waits 2 s between pages.

History depth: `/posts.json?before=<id>` pages back to a forum's first post. The backfill stops at
W's start minus 30 days (2024-08-31).

Timestamp classes: `created_at` and `updated_at` are server-set by Discourse. Imports and admin
edits can rewrite them; the live reconciliation measures how often.

knownAt rule, fixed 2026-10-19 before any live measurement: a post's existence is known at
`created_at` + 600 s, and its content at `updated_at` + 600 s. C5.3 failed as written (a −4.9 s clock reading,
and realized poll gaps). Under the stage 5 amendment of 2026-10-22, the claimed times are therefore never
admitted. Discourse is prospective only, and a post is known 60 s after its earliest observation
(`derived.md`). The claimed-time rule is still measured and reported. Raw revisions are known when fetched,
and a post the backfill no longer lists becomes a tombstone.

## Terms: delvingbitcoin.org

- URL: https://delvingbitcoin.org/tos
- Retrieved: 2026-10-22
- Basis: permitting clause

> You may automate access to the forum, or monitor the forum, such as with a web crawler, browser plug-in or
> add-on, or other computer program that is not a web browser.

The same terms forbid straining the forum "with an unreasonable volume of requests"; 1 request per
5 minutes is far from that.
