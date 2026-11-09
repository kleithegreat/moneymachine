//! Admission on metadata and event times (reference/lean/Ref/Source.lean: `Roles`, `Cert`, `Binding`, `Meta`,
//! `stage1`, `stage2`; Sim.lean: `admit`'s positions 1 to 5): nothing here reads a stored payload.

use crate::sim::Abort;
use crate::source::{self, Cadence, Declaration};
use std::collections::{BTreeMap, BTreeSet};

/// The run manifest's provider of each role, as registry indices.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Roles {
    pub bars: usize,
    pub settlement: usize,
}

impl Roles {
    pub fn valid(&self, reg: &[Declaration]) -> bool {
        let provides = |s: usize, role: &str| reg.get(s).is_some_and(|d| d.roles.contains_key(role));
        self.bars != self.settlement && provides(self.bars, "bars") && provides(self.settlement, "settlement")
    }
}

/// A certificate's payload as the verifier wrote it; its id is the hash of this payload (CERTIFICATES.md).
pub struct Cert {
    pub id: String,
    pub decl: String,
    pub manifest: String,
    pub policy: String,
    pub verifier: String,
    pub upstream: Vec<String>,
    pub controls: BTreeSet<String>,
    pub venue_state: bool,
}

/// A binding: the bound dataset's content identity and its certificate.
pub struct Binding {
    pub dataset: String,
    pub cert: String,
}

#[derive(Clone, Copy, PartialEq)]
pub enum Mode {
    Search,
    Holdout,
}

/// Everything admission knows before any stored row is read.
pub struct Meta {
    pub bindings: BTreeMap<usize, Binding>,
    pub certs: Vec<Cert>,
    /// (certificate id, ledger position of its supersession).
    pub supersessions: Vec<(String, u64)>,
    pub position: u64,
    pub policy: String,
    pub verifier: String,
    pub holdout: Vec<String>,
    pub holdout_start: i64,
}

impl Meta {
    fn cert(&self, h: &str) -> Option<&Cert> {
        self.certs.iter().find(|k| k.id == h)
    }

    /// Issued, not superseded at the admission position, and so are its upstream certificates.
    fn valid(&self, fuel: usize, h: &str) -> bool {
        fuel > 0
            && self.cert(h).is_some_and(|k| {
                !self.supersessions.iter().any(|(x, pos)| x == h && *pos <= self.position)
                    && k.upstream.iter().all(|u| self.valid(fuel - 1, u))
            })
    }

    /// The certificate is for this declaration, dataset, policy, verifier and upstream certificates; it authorizes
    /// the declaration's control columns; and a role provider's attests venue state.
    fn matches(&self, reg: &[Declaration], roles: &Roles, s: usize, b: &Binding, k: &Cert) -> bool {
        let d = &reg[s];
        let deps: Vec<&String> = source::depends(reg, d).iter().filter_map(|u| self.bindings.get(u)).map(|b| &b.cert).collect();
        k.decl == d.hash && k.manifest == b.dataset && k.policy == self.policy && k.verifier == self.verifier
            && k.upstream.iter().all(|u| deps.contains(&u)) && deps.iter().all(|u| k.upstream.contains(u))
            && d.controls().iter().all(|c| k.controls.contains(*c))
            && (k.venue_state || (s != roles.bars && s != roles.settlement))
    }

    /// The required set: every bound non-evidence source (version 1 delivers every dataset in the store), the
    /// program's sources and the role providers, with their transitive dependencies, in Lean's `closure` order.
    fn required(&self, reg: &[Declaration], roles: &Roles, sources: &[usize]) -> Vec<usize> {
        let delivered = (0..reg.len()).filter(|s| self.bindings.contains_key(s) && reg[*s].cadence != Cadence::Evidence);
        let mut out: Vec<usize> = vec![];
        let mut level: Vec<usize> = delivered.chain(sources.iter().copied()).chain([roles.bars, roles.settlement]).collect();
        while !level.is_empty() {
            let mut next = vec![];
            for s in level {
                if !out.contains(&s) {
                    out.push(s);
                    next.extend(source::depends(reg, &reg[s]));
                }
            }
            level = next;
        }
        out
    }
}

/// Admission stage 1, on metadata only: the required set, or the refusal.
pub fn stage1(reg: &[Declaration], roles: &Roles, sources: &[usize], m: &Meta, mode: Mode) -> Result<Vec<usize>, Abort> {
    if !roles.valid(reg) {
        return Err(Abort::Roles("the run's role providers".into()));
    }
    let req = m.required(reg, roles, sources);
    if let Some(s) = req.iter().find(|s| !m.bindings.contains_key(s)) {
        return Err(Abort::InputUnavailable(format!("{} is not bound", reg[*s].name)));
    }
    if mode == Mode::Search {
        if let Some(s) = req.iter().find(|s| m.holdout.contains(&m.bindings[s].dataset)) {
            return Err(Abort::Holdout(format!("{} is bound to a holdout dataset", reg[*s].name)));
        }
    }
    for s in &req {
        let b = &m.bindings[s];
        if !m.cert(&b.cert).is_some_and(|k| m.valid(m.certs.len(), &b.cert) && m.matches(reg, roles, *s, b, k)) {
            return Err(Abort::Uncertified(format!("{}: certificate {}", reg[*s].name, b.cert)));
        }
    }
    Ok(req)
}

/// Admission stage 2, on the required datasets' event-time columns only (I8).
pub fn stage2(m: &Meta, mode: Mode, rows: &[(usize, i64)]) -> Result<(), Abort> {
    match rows.iter().find(|r| r.1 >= m.holdout_start) {
        Some((s, t)) if mode == Mode::Search => Err(Abort::Holdout(format!("source {s}: eventTime {t} >= holdout start"))),
        _ => Ok(()),
    }
}

/// Admission's metadata and event-time checks, each refusal with its position (Lean's `admit`, positions 1 to 5);
/// `rows` reads the event-time column of every stored row of the required datasets.
pub fn admit(reg: &[Declaration], roles: &Roles, sources: &[usize], m: &Meta, mode: Mode,
             rows: impl FnOnce(&[usize]) -> Vec<(usize, i64)>) -> Result<Vec<usize>, (u8, Abort)> {
    let req = stage1(reg, roles, sources, m, mode).map_err(|e| {
        let position = match e {
            Abort::Roles(_) => 1,
            Abort::InputUnavailable(_) => 2,
            Abort::Holdout(_) => 3,
            _ => 4,
        };
        (position, e)
    })?;
    stage2(m, mode, &rows(&req)).map_err(|e| (5, e))?;
    Ok(req)
}
