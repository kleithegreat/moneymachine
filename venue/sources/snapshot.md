# Snapshot (stage 5 governance source)

Public GraphQL hub `https://hub.snapshot.org/graphql`, read-only, polled by
`ingest/sources_record.py` every 5 minutes: the space's 20 newest proposals. Mapping:
`aavedao.eth` → AAVE (987 proposals as of 2026-10-19). No other coin of U has a Snapshot space
we found (aave.eth is empty; sui.eth, celestia.eth, worldcoin.eth, popcat.eth, bnbchain.eth and
fantom.eth do not exist). Rate limit: anonymous hub use is documented as limited; we make 1
request per 5 minutes.

Timestamp classes: a proposal's `created` comes from the author's signed message. It is
client-claimed unless the hub's validation of message timestamps is established, so it cannot
anchor backfill on its own. `start` and `end` are values (the scheduled voting window), not
availability times.

knownAt rule, fixed 2026-10-19 before any live measurement: knownAt = max(`created` + 600 s,
earliest witness). Until a witness or validated hub enforcement is established, backfilled
proposals are usable only prospectively, with knownAt = fetchedAt.
