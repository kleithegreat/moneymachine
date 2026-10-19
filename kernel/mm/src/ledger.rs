//! The experiment ledger: append-only SQLite. Triggers abort every UPDATE and DELETE.

use rusqlite::{params, Connection};
use std::path::Path;

const TABLES: [&str; 5] = ["strategies", "experiments", "results", "disclosures", "selections"];

const SCHEMA: &str = "
CREATE TABLE IF NOT EXISTS strategies(hash TEXT PRIMARY KEY, canonical TEXT NOT NULL, created INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS experiments(
  id INTEGER PRIMARY KEY, created INTEGER NOT NULL, campaign TEXT NOT NULL, agent TEXT NOT NULL, mode TEXT NOT NULL,
  strategy_hash TEXT NOT NULL, params TEXT NOT NULL, universe TEXT NOT NULL, window_start INTEGER NOT NULL,
  window_end INTEGER NOT NULL, dataset_version INTEGER NOT NULL, data_hash TEXT NOT NULL, conventions TEXT NOT NULL,
  rules_hash TEXT NOT NULL, execution_hash TEXT NOT NULL, kernel TEXT NOT NULL, seed INTEGER NOT NULL,
  identity TEXT NOT NULL, mechanism TEXT NOT NULL, program TEXT NOT NULL, equivalence TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS results(experiment_id INTEGER PRIMARY KEY, returns BLOB NOT NULL, summary TEXT NOT NULL,
  result_hash TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS disclosures(id INTEGER PRIMARY KEY, created INTEGER NOT NULL, campaign TEXT NOT NULL,
  agent TEXT NOT NULL, experiment_id INTEGER, kind TEXT NOT NULL, content TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS selections(id INTEGER PRIMARY KEY, created INTEGER NOT NULL, campaign TEXT NOT NULL,
  agent TEXT NOT NULL, strategy_hash TEXT NOT NULL, seen_through INTEGER NOT NULL, note TEXT NOT NULL);
";

pub struct Ledger {
    pub conn: Connection,
}

pub struct Experiment<'a> {
    pub campaign: &'a str,
    pub agent: &'a str,
    pub mode: &'a str,
    pub strategy_hash: &'a str,
    pub canonical: &'a str,
    /// The exact submitted program text.
    pub program: &'a str,
    /// The equivalence key (kernel/CANONICAL.md).
    pub equivalence: &'a str,
    pub params: &'a str,
    pub universe: &'a str,
    pub window: (i64, i64),
    pub dataset_version: i64,
    pub data_hash: &'a str,
    pub conventions: &'a str,
    pub rules_hash: &'a str,
    pub execution_hash: &'a str,
    pub kernel: &'a str,
    pub seed: i64,
    pub identity: &'a str,
    pub mechanism: &'a str,
}

fn now() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map_or(0, |d| d.as_millis() as i64)
}

impl Ledger {
    pub fn open(path: &Path) -> rusqlite::Result<Ledger> {
        let conn = Connection::open(path)?;
        conn.execute_batch(SCHEMA)?;
        for t in TABLES {
            for op in ["UPDATE", "DELETE"] {
                conn.execute_batch(&format!(
                    "CREATE TRIGGER IF NOT EXISTS no_{op}_{t} BEFORE {op} ON {t} BEGIN SELECT RAISE(ABORT, 'ledger is append-only'); END;"
                ))?;
            }
        }
        Ok(Ledger { conn })
    }

    /// Commit an experiment, its result and the disclosure of `content` in one transaction.
    pub fn disclose_result(
        &mut self,
        e: &Experiment,
        returns: &[f64],
        summary: &str,
        result_hash: &str,
        content: &str,
    ) -> rusqlite::Result<i64> {
        let tx = self.conn.transaction()?;
        let t = now();
        tx.execute(
            "INSERT OR IGNORE INTO strategies(hash, canonical, created) VALUES (?1, ?2, ?3)",
            params![e.strategy_hash, e.canonical, t],
        )?;
        tx.execute(
            "INSERT INTO experiments(created, campaign, agent, mode, strategy_hash, params, universe, window_start,
             window_end, dataset_version, data_hash, conventions, rules_hash, execution_hash, kernel, seed, identity, mechanism,
             program, equivalence)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20)",
            params![
                t, e.campaign, e.agent, e.mode, e.strategy_hash, e.params, e.universe, e.window.0, e.window.1,
                e.dataset_version, e.data_hash, e.conventions, e.rules_hash, e.execution_hash, e.kernel, e.seed,
                e.identity, e.mechanism, e.program, e.equivalence
            ],
        )?;
        let id = tx.last_insert_rowid();
        let blob: Vec<u8> = returns.iter().flat_map(|r| r.to_le_bytes()).collect();
        tx.execute(
            "INSERT INTO results(experiment_id, returns, summary, result_hash) VALUES (?1, ?2, ?3, ?4)",
            params![id, blob, summary, result_hash],
        )?;
        tx.execute(
            "INSERT INTO disclosures(created, campaign, agent, experiment_id, kind, content) VALUES (?1, ?2, ?3, ?4, 'eval', ?5)",
            params![t, e.campaign, e.agent, id, content],
        )?;
        tx.commit()?;
        Ok(id)
    }

    /// Commit a disclosure that carries no experiment (check results, rejections, aborts).
    pub fn disclose(&mut self, campaign: &str, agent: &str, kind: &str, content: &str) -> rusqlite::Result<i64> {
        self.conn.execute(
            "INSERT INTO disclosures(created, campaign, agent, experiment_id, kind, content) VALUES (?1, ?2, ?3, NULL, ?4, ?5)",
            params![now(), campaign, agent, kind, content],
        )?;
        Ok(self.conn.last_insert_rowid())
    }

    /// Whether a holdout run over a window overlapping [start, end) is already recorded.
    pub fn holdout_used(&self, start: i64, end: i64) -> rusqlite::Result<bool> {
        self.conn.query_row(
            "SELECT COUNT(*) > 0 FROM experiments WHERE mode = 'holdout' AND window_start < ?2 AND window_end > ?1",
            params![start, end],
            |r| r.get(0),
        )
    }

    pub fn select(&mut self, campaign: &str, agent: &str, strategy_hash: &str, note: &str) -> rusqlite::Result<i64> {
        let seen: i64 = self.conn.query_row(
            "SELECT COALESCE(MAX(id), 0) FROM disclosures WHERE campaign = ?1 AND agent = ?2",
            params![campaign, agent],
            |r| r.get(0),
        )?;
        self.conn.execute(
            "INSERT INTO selections(created, campaign, agent, strategy_hash, seen_through, note) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![now(), campaign, agent, strategy_hash, seen, note],
        )?;
        Ok(self.conn.last_insert_rowid())
    }
}
