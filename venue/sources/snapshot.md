# Snapshot (stage 5 governance source)

Public GraphQL hub `https://hub.snapshot.org/graphql`, read-only, polled by
`ingest/sources_record.py` every 5 minutes: the space's 20 newest proposals. Mapping:
`aavedao.eth` → AAVE (987 proposals as of 2026-10-19). No other coin of U has a Snapshot space
we found (aave.eth is empty; sui.eth, celestia.eth, worldcoin.eth, popcat.eth, bnbchain.eth and
fantom.eth do not exist).

Timestamp classes: a proposal's `created` comes from the author's signed message. It is
client-claimed unless the hub's validation of message timestamps is established, so it cannot
anchor backfill on its own. `start` and `end` are values (the scheduled voting window), not
availability times.

knownAt rule: `created` is never admitted, so a proposal is known at its earliest observation by
the recorder or a fetch, and only proposals created at or after the first poll count (`derived.md`).

Rate limit: "No API Key: 100 requests per minute" ([API keys](https://docs.snapshot.box/tools/api/api-keys),
retrieved 2026-10-22). We make 1 request per 5 minutes. History depth: the `proposals` query pages back
to a space's first proposal; it is not used, since Snapshot is prospective only.

## Terms: hub.snapshot.org

- URL: https://docs.snapshot.box/tools/api
- Retrieved: 2026-10-22
- Basis: official API

> You can use the Hub GraphQL API to create flexible queries for the data you need to integrate with Snapshot.
> There is a limit of 100 requests per minute with the API, to get higher limits please apply for an API Key

No separate terms of service for the hub were found (snapshot.box and docs.snapshot.box, 2026-10-22).
