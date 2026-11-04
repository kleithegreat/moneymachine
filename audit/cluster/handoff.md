# Recorder handoff to the cluster (CLUSTER.md section 6)

Figures: `handoff.json`. Reconciled 2026-10-30 01:00–01:20 UTC (2026-10-29 21:00–21:20 EDT) from the mirror
(`/srv/moneymachine/mirror`), the Oracle pull (`data/live-oci/gae5h5prtpta`) and this PC's directories.

## Handoff instants

All three of this PC's recorders ended at the human's reboot. There was no SIGTERM:
the shutdown was at 2026-10-29 01:54 UTC (2026-10-28 21:54 EDT) and the boot at 04:59 UTC (00:59 EDT), and with `mm-recorders-up` removed none
restarted. Each instant is the last poll in its directory, and each directory closes there as a host.

| Recorder | This PC's last poll (handoff) | Cluster's first poll |
|---|---|---|
| `hl` (`data/live`) | 2026-10-29 01:52:55.619 UTC (21:52:55 EDT) | 2026-10-28 17:58:19.544 UTC (13:58 EDT) |
| `sources` (`data/sources_live`) | 2026-10-29 01:52:24.499 UTC (21:52:24 EDT) | 2026-10-28 17:58:23.191 UTC |
| `datalayer` (`data/datalayer`) | 2026-10-29 01:48:11.275 UTC (21:48:11 EDT) | 2026-10-28 17:58:26.047 UTC |

The reboot came before the checks below, so they are retrospective: they cover the overlaps as they ended.

## Checks

- **Hyperliquid against Oracle,** over [2026-10-28 17:58:19 UTC (13:58 EDT), 2026-10-30 01:00 UTC (2026-10-29 21:00 EDT)), 31 h:
  - The same 11 coins on both hosts. L2 cadence on the cluster: median 30.26 s, max 40.1 s, none over 60 s (Oracle:
    30.23 s, max 33.8 s).
  - All 429 funding and bar boundaries are on both hosts, with equal settled values.
  - On the cluster (and on this PC over its overlap), the first poll of AAVE, BNB, POPCAT and WLD's 4 h bars comes
    about 65 s after the boundary, past the 35 s completeness gap; on Oracle it comes at 9 s. The cause is the
    480/min budget shared with this PC; Oracle runs at 600/min.
- **Hyperliquid against this PC,** over the overlap up to the handoff: all 110 boundaries on both, equal values, the
  same 10,352 L2 polls, and the same incomplete bars.
- **Sources against this PC:** the same 72 items with the same revisions. On the cluster over 31.2 h, poll gaps are
  at most 302 s (cadence 300 s), with no failed poll and no poll sharing nothing with the previous one (pagination).
- **Datalayer against this PC:**
  - Every feed this PC polled in the overlap, the cluster polled too. The cluster also polled 605 more, all first polls
    of a fresh recorder (Fed DDP packages, Treasury years).
  - Bodies this PC saw that the cluster did not differ only in response metadata (BEA's `UTCProductionTime`, BLS's
    `responseTime`), or come from snapshot feeds sampled at other moments (SEC's filing RSS, NWS alerts, Polymarket
    top lists, GDELT's latest file).
  - GDELT reads `lastupdate.txt` only, so each host skips the odd 15-minute file, at different times on each.
- **Last poll under one cadence old,** at the mirror run of 2026-10-30 01:10 UTC (2026-10-29 21:10 EDT): `hl` 1.9 s (cadence 30 s),
  `sources` 97 s (300 s), `datalayer` 140 s (900 s).
- **Clock:**
  - The cluster's clock log is empty of readings. Every `timesyncd` entry is `FileNotFoundError`, because the image has
    no `timedatectl` (Blockers, PROGRESS.md).
  - Measured instead against Hyperliquid's server time (the L2 snapshot's `time` minus the poll's send/receive
    midpoint), the median is −617.5 ms on the cluster, −613.0 ms on Oracle and −621.5 ms on this PC. That is the
    venue's snapshot age, the same on every host.
  - Oracle's NTP offset stayed under 0.77 ms over the window, so prodesk7's clock, which all three pods share, is
    within about 5 ms of it: under 1 s.
- **Mirror:** each volume's manifest of 2026-10-30 01:10 UTC (2026-10-29 21:10 EDT) lists the day file holding its handoff instant. The
  cluster's polls in the mirror run unbroken through the outage,
  2026-10-29 01:54 UTC (2026-10-28 21:54 EDT) to 04:59 UTC (00:59 EDT), so the mirror caught up. `mirror-verify` passed at its scheduled run (2026-10-29 08:41 UTC (04:41 EDT)) and at a
  one-off run (2026-10-30 01:16 UTC (2026-10-29 21:16 EDT)).
- **Thesis:** `thesis-0` ran the 2026-10-29 sessions under `thesis-62476ec60a1b` (`main` from 02:58:42 UTC (2026-10-28 22:58 EDT), then
  `noread`), both ending in `success`.
