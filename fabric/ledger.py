"""Plane 5: Append-only, hash-chained SQLite Prospective Forecast Ledger."""

from __future__ import annotations

import hashlib
import json
import math
import sqlite3
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


def _to_utc_iso(ts: datetime | str) -> str:
    parsed = datetime.fromisoformat(ts.replace("Z", "+00:00")) if isinstance(ts, str) else ts
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC).isoformat()


def _compute_entry_hash(
    *,
    forecast_id: str,
    pod_id: str,
    submitted_at: str,
    entity_id: str,
    target_event: str,
    horizon_end: str,
    prob_estimate: float,
    crowd_baseline: float | None,
    rationale_json: str,
    prev_hash: str,
) -> str:
    payload = json.dumps(
        {
            "forecast_id": forecast_id,
            "pod_id": pod_id,
            "submitted_at": submitted_at,
            "entity_id": entity_id,
            "target_event": target_event,
            "horizon_end": horizon_end,
            "prob_estimate": prob_estimate,
            "crowd_baseline": crowd_baseline,
            "rationale_citations": json.loads(rationale_json),
            "prev_hash": prev_hash,
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class ForecastEntry:
    """A single immutable forecast registered in the hash-chained ledger."""

    seq: int
    forecast_id: str
    pod_id: str
    submitted_at: str
    entity_id: str
    target_event: str
    horizon_end: str
    prob_estimate: float
    crowd_baseline: float | None
    rationale_citations: list[dict[str, Any]]
    prev_hash: str
    entry_hash: str


class ForecastLedger:
    """Append-only SQLite ledger with UPDATE/DELETE triggers and SHA-256 hash chaining."""

    GENESIS_HASH = "0" * 64

    def __init__(self, db_path: Path | str) -> None:
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        con = sqlite3.connect(self.db_path, isolation_level=None)
        con.execute("PRAGMA foreign_keys = ON;")
        con.row_factory = sqlite3.Row
        return con

    def _init_schema(self) -> None:
        with self._connect() as con:
            con.executescript(
                """
                CREATE TABLE IF NOT EXISTS forecasts (
                    seq INTEGER PRIMARY KEY AUTOINCREMENT,
                    forecast_id TEXT UNIQUE NOT NULL,
                    pod_id TEXT NOT NULL,
                    submitted_at TEXT NOT NULL,
                    entity_id TEXT NOT NULL,
                    target_event TEXT NOT NULL,
                    horizon_end TEXT NOT NULL,
                    prob_estimate REAL NOT NULL CHECK (prob_estimate >= 0.0 AND prob_estimate <= 1.0),
                    crowd_baseline REAL CHECK (crowd_baseline IS NULL OR (crowd_baseline >= 0.0 AND crowd_baseline <= 1.0)),
                    rationale_citations TEXT NOT NULL,
                    prev_hash TEXT NOT NULL,
                    entry_hash TEXT UNIQUE NOT NULL
                );
                CREATE TABLE IF NOT EXISTS resolutions (
                    seq INTEGER PRIMARY KEY AUTOINCREMENT,
                    forecast_id TEXT UNIQUE NOT NULL REFERENCES forecasts(forecast_id),
                    resolved_at TEXT NOT NULL,
                    outcome INTEGER NOT NULL CHECK (outcome IN (0, 1)),
                    evidence_hash TEXT NOT NULL
                );
                CREATE TRIGGER IF NOT EXISTS forecasts_no_update
                BEFORE UPDATE ON forecasts
                BEGIN
                    SELECT RAISE(ABORT, 'append-only ledger: UPDATE on forecasts forbidden');
                END;
                CREATE TRIGGER IF NOT EXISTS forecasts_no_delete
                BEFORE DELETE ON forecasts
                BEGIN
                    SELECT RAISE(ABORT, 'append-only ledger: DELETE on forecasts forbidden');
                END;
                CREATE TRIGGER IF NOT EXISTS resolutions_no_update
                BEFORE UPDATE ON resolutions
                BEGIN
                    SELECT RAISE(ABORT, 'append-only ledger: UPDATE on resolutions forbidden');
                END;
                CREATE TRIGGER IF NOT EXISTS resolutions_no_delete
                BEFORE DELETE ON resolutions
                BEGIN
                    SELECT RAISE(ABORT, 'append-only ledger: DELETE on resolutions forbidden');
                END;
                """
            )

    def submit_forecast(
        self,
        *,
        pod_id: str,
        entity_id: str,
        target_event: str,
        horizon_end: datetime | str,
        prob_estimate: float,
        rationale_citations: Sequence[dict[str, Any]],
        crowd_baseline: float | None = None,
        submitted_at: datetime | str | None = None,
        forecast_id: str | None = None,
    ) -> ForecastEntry:
        """Append a new forecast chained onto the previous entry hash."""
        if not (0.0 <= prob_estimate <= 1.0) or math.isnan(prob_estimate):
            raise ValueError(f"prob_estimate must lie in [0, 1], got {prob_estimate!r}")
        if crowd_baseline is not None and (not (0.0 <= crowd_baseline <= 1.0) or math.isnan(crowd_baseline)):
            raise ValueError(f"crowd_baseline must lie in [0, 1], got {crowd_baseline!r}")

        fid = forecast_id or str(uuid.uuid4())
        sub_iso = _to_utc_iso(submitted_at or datetime.now(UTC))
        hor_iso = _to_utc_iso(horizon_end)
        citations_list = [dict(c) for c in rationale_citations]
        rationale_json = json.dumps(citations_list, sort_keys=True, separators=(",", ":"))

        with self._connect() as con:
            con.execute("BEGIN IMMEDIATE")
            try:
                last = con.execute("SELECT entry_hash FROM forecasts ORDER BY seq DESC LIMIT 1").fetchone()
                prev_hash = str(last["entry_hash"]) if last is not None else self.GENESIS_HASH
                entry_hash = _compute_entry_hash(
                    forecast_id=fid,
                    pod_id=pod_id,
                    submitted_at=sub_iso,
                    entity_id=entity_id,
                    target_event=target_event,
                    horizon_end=hor_iso,
                    prob_estimate=float(prob_estimate),
                    crowd_baseline=float(crowd_baseline) if crowd_baseline is not None else None,
                    rationale_json=rationale_json,
                    prev_hash=prev_hash,
                )
                cur = con.execute(
                    """
                    INSERT INTO forecasts (
                        forecast_id, pod_id, submitted_at, entity_id, target_event, horizon_end,
                        prob_estimate, crowd_baseline, rationale_citations, prev_hash, entry_hash
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        fid,
                        pod_id,
                        sub_iso,
                        entity_id,
                        target_event,
                        hor_iso,
                        float(prob_estimate),
                        float(crowd_baseline) if crowd_baseline is not None else None,
                        rationale_json,
                        prev_hash,
                        entry_hash,
                    ),
                )
                seq = int(cur.lastrowid or 0)
                con.execute("COMMIT")
            except Exception:
                con.execute("ROLLBACK")
                raise

        return ForecastEntry(
            seq=seq,
            forecast_id=fid,
            pod_id=pod_id,
            submitted_at=sub_iso,
            entity_id=entity_id,
            target_event=target_event,
            horizon_end=hor_iso,
            prob_estimate=float(prob_estimate),
            crowd_baseline=float(crowd_baseline) if crowd_baseline is not None else None,
            rationale_citations=citations_list,
            prev_hash=prev_hash,
            entry_hash=entry_hash,
        )

    def resolve_forecast(
        self,
        forecast_id: str,
        outcome: int,
        evidence_hash: str,
        *,
        resolved_at: datetime | str | None = None,
    ) -> None:
        """Record an immutable binary outcome {0, 1} for an existing forecast."""
        if outcome not in (0, 1):
            raise ValueError(f"outcome must be 0 or 1, got {outcome!r}")
        res_iso = _to_utc_iso(resolved_at or datetime.now(UTC))
        with self._connect() as con:
            con.execute("BEGIN IMMEDIATE")
            try:
                con.execute(
                    "INSERT INTO resolutions (forecast_id, resolved_at, outcome, evidence_hash) VALUES (?, ?, ?, ?)",
                    (forecast_id, res_iso, outcome, evidence_hash),
                )
                con.execute("COMMIT")
            except Exception:
                con.execute("ROLLBACK")
                raise

    def verify_chain(self) -> bool:
        """Recompute every SHA-256 link in `forecasts` from genesis."""
        with self._connect() as con:
            rows = con.execute("SELECT * FROM forecasts ORDER BY seq ASC").fetchall()
        expected_prev = self.GENESIS_HASH
        for row in rows:
            if row["prev_hash"] != expected_prev:
                return False
            expected_hash = _compute_entry_hash(
                forecast_id=str(row["forecast_id"]),
                pod_id=str(row["pod_id"]),
                submitted_at=str(row["submitted_at"]),
                entity_id=str(row["entity_id"]),
                target_event=str(row["target_event"]),
                horizon_end=str(row["horizon_end"]),
                prob_estimate=float(row["prob_estimate"]),
                crowd_baseline=float(row["crowd_baseline"]) if row["crowd_baseline"] is not None else None,
                rationale_json=str(row["rationale_citations"]),
                prev_hash=expected_prev,
            )
            if row["entry_hash"] != expected_hash:
                return False
            expected_prev = expected_hash
        return True

    def count_forecasts(self, pod_id: str | None = None) -> int:
        with self._connect() as con:
            if pod_id is None:
                row = con.execute("SELECT COUNT(*) FROM forecasts").fetchone()
            else:
                row = con.execute("SELECT COUNT(*) FROM forecasts WHERE pod_id = ?", (pod_id,)).fetchone()
        return int(row[0]) if row is not None else 0

    def score_summary(self, pod_id: str | None = None) -> dict[str, float | int]:
        """Compute out-of-sample Brier score, log loss, and skill vs crowd baseline."""
        with self._connect() as con:
            total = self.count_forecasts(pod_id)
            where = "WHERE f.pod_id = ?" if pod_id is not None else ""
            params = (pod_id,) if pod_id is not None else ()
            rows = con.execute(
                f"""
                SELECT f.prob_estimate, f.crowd_baseline, r.outcome
                FROM forecasts f
                JOIN resolutions r ON f.forecast_id = r.forecast_id
                {where}
                ORDER BY f.seq ASC
                """,
                params,
            ).fetchall()
        if not rows:
            return {"total_forecasts": total, "resolved_count": 0}

        briers: list[float] = []
        losses: list[float] = []
        crowd_briers: list[float] = []
        paired_agent_briers: list[float] = []
        eps = 1e-15
        for row in rows:
            p = min(max(float(row["prob_estimate"]), eps), 1.0 - eps)
            y = float(row["outcome"])
            brier = (float(row["prob_estimate"]) - y) ** 2
            briers.append(brier)
            losses.append(-(y * math.log(p) + (1.0 - y) * math.log(1.0 - p)))
            if row["crowd_baseline"] is not None:
                cb = float(row["crowd_baseline"])
                crowd_briers.append((cb - y) ** 2)
                paired_agent_briers.append(brier)

        n = len(rows)
        summary: dict[str, float | int] = {
            "total_forecasts": total,
            "resolved_count": n,
            "mean_brier": sum(briers) / n,
            "mean_log_loss": sum(losses) / n,
        }
        if crowd_briers:
            crowd_mean = sum(crowd_briers) / len(crowd_briers)
            agent_paired = sum(paired_agent_briers) / len(paired_agent_briers)
            summary["crowd_mean_brier"] = crowd_mean
            summary["brier_skill_vs_crowd"] = 1.0 - (agent_paired / crowd_mean) if crowd_mean > 0 else 0.0
        return summary
