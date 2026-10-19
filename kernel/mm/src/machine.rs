//! The DSL interpreter: a causal machine on the hourly clock (DSL.md, Time and evaluation).
//!
//! Observations enter only through `deliver`, which enforces I1. `tick` evaluates every
//! node for every listed coin; values are `None` when undefined or non-finite.

use crate::dsl::{Input, Node, Op, Program, Window};
use crate::market::{Bar, Event, Funding, HOUR};
use std::collections::VecDeque;

#[derive(Debug, PartialEq)]
pub struct Causality {
    pub known: i64,
    pub tick: i64,
}

enum Win {
    Lag { k: usize, buf: VecDeque<Option<f64>> },
    Sums { kind: Window, n: usize, buf: VecDeque<Option<f64>>, sum: f64, sumsq: f64, nones: usize, since_exact: usize },
    Extreme { max: bool, n: usize, seq: u64, last_none: Option<u64>, deque: VecDeque<(u64, f64)> },
    Ema { n: usize, alpha: f64, s: f64, seen: usize },
}

impl Win {
    fn new(w: Window, n: usize) -> Win {
        match w {
            Window::Lag => Win::Lag { k: n, buf: VecDeque::with_capacity(n + 1) },
            Window::Mean | Window::Sum | Window::Std => {
                Win::Sums { kind: w, n, buf: VecDeque::with_capacity(n), sum: 0.0, sumsq: 0.0, nones: 0, since_exact: 0 }
            }
            Window::MinOver | Window::MaxOver => {
                Win::Extreme { max: w == Window::MaxOver, n, seq: 0, last_none: None, deque: VecDeque::new() }
            }
            Window::Ema => Win::Ema { n, alpha: 2.0 / (n as f64 + 1.0), s: 0.0, seen: 0 },
        }
    }

    fn push(&mut self, x: Option<f64>) -> Option<f64> {
        match self {
            Win::Lag { k, buf } => {
                buf.push_back(x);
                if buf.len() > *k + 1 {
                    buf.pop_front();
                }
                if buf.len() == *k + 1 { buf[0] } else { None }
            }
            Win::Sums { kind, n, buf, sum, sumsq, nones, since_exact } => {
                buf.push_back(x);
                match x {
                    Some(v) => {
                        *sum += v;
                        *sumsq += v * v
                    }
                    None => *nones += 1,
                }
                if buf.len() > *n {
                    match buf.pop_front().unwrap() {
                        Some(v) => {
                            *sum -= v;
                            *sumsq -= v * v
                        }
                        None => *nones -= 1,
                    }
                }
                *since_exact += 1;
                if *since_exact >= *n {
                    *since_exact = 0;
                    *sum = buf.iter().flatten().sum();
                    *sumsq = buf.iter().flatten().map(|v| v * v).sum();
                }
                if buf.len() < *n || *nones > 0 {
                    return None;
                }
                let m = *sum / *n as f64;
                match kind {
                    Window::Sum => Some(*sum),
                    Window::Mean => Some(m),
                    _ => Some((*sumsq / *n as f64 - m * m).max(0.0).sqrt()),
                }
            }
            Win::Extreme { max, n, seq, last_none, deque } => {
                *seq += 1;
                match x {
                    None => *last_none = Some(*seq),
                    Some(v) => {
                        while deque.back().is_some_and(|&(_, b)| if *max { b <= v } else { b >= v }) {
                            deque.pop_back();
                        }
                        deque.push_back((*seq, v));
                    }
                }
                let start = *seq as i64 - *n as i64 + 1;
                while deque.front().is_some_and(|&(s, _)| (s as i64) < start) {
                    deque.pop_front();
                }
                if start < 1 || last_none.is_some_and(|s| s as i64 >= start) {
                    None
                } else {
                    deque.front().map(|&(_, v)| v)
                }
            }
            Win::Ema { n, alpha, s, seen } => {
                let v = x?;
                *s = if *seen == 0 { v } else { *alpha * v + (1.0 - *alpha) * *s };
                *seen += 1;
                if *seen >= *n { Some(*s) } else { None }
            }
        }
    }
}

pub struct Machine<'p> {
    prog: &'p Program,
    coins: usize,
    vals: Vec<Vec<Option<f64>>>,
    wins: Vec<Vec<Option<Win>>>,
    pub funding: Vec<Option<Funding>>,
    pub bar: Vec<Option<Bar>>,
    /// Latest delivered hourly event row per (event input, coin).
    events: Vec<Vec<Option<Event>>>,
    /// Per node and coin: the last hour a `hours_since` condition held.
    since: Vec<Vec<Option<i64>>>,
    hour: i64,
    /// Largest knownAt delivered so far, over all coins.
    pub max_known: i64,
}

fn finite(x: f64) -> Option<f64> {
    x.is_finite().then_some(x)
}

impl<'p> Machine<'p> {
    pub fn new(prog: &'p Program, coins: usize) -> Machine<'p> {
        let wins = prog
            .nodes
            .iter()
            .map(|n| match n {
                Node::Op(Op::Window(w, h), _) => (0..coins).map(|_| Some(Win::new(*w, *h as usize))).collect(),
                _ => (0..coins).map(|_| None).collect(),
            })
            .collect();
        Machine {
            prog,
            coins,
            vals: vec![vec![None; coins]; prog.nodes.len()],
            wins,
            funding: vec![None; coins],
            bar: vec![None; coins],
            events: vec![vec![None; coins]; 2],
            since: vec![vec![None; coins]; prog.nodes.len()],
            hour: i64::MIN,
            max_known: i64::MIN,
        }
    }

    pub fn deliver_funding(&mut self, f: Funding, tick: i64) -> Result<(), Causality> {
        if f.known > tick {
            return Err(Causality { known: f.known, tick });
        }
        self.max_known = self.max_known.max(f.known);
        self.funding[f.coin] = Some(f);
        Ok(())
    }

    pub fn deliver_bar(&mut self, b: Bar, tick: i64) -> Result<(), Causality> {
        if b.known > tick {
            return Err(Causality { known: b.known, tick });
        }
        self.max_known = self.max_known.max(b.known);
        self.bar[b.coin] = Some(b);
        Ok(())
    }

    /// `slot` is 0 for forum posts, 1 for governance proposals.
    pub fn deliver_event(&mut self, slot: usize, e: Event, tick: i64) -> Result<(), Causality> {
        if e.known > tick {
            return Err(Causality { known: e.known, tick });
        }
        self.max_known = self.max_known.max(e.known);
        self.events[slot][e.coin] = Some(e);
        Ok(())
    }

    fn input(&self, i: Input, c: usize) -> Option<f64> {
        let fresh = |slot: usize| self.events[slot][c].filter(|e| e.event == self.hour).map(|e| e.count);
        match i {
            Input::ForumPosts => fresh(0),
            Input::Proposals => fresh(1),
            Input::Funding => self.funding[c].map(|f| f.rate),
            Input::Premium => self.funding[c].map(|f| f.premium),
            Input::Open | Input::High | Input::Low | Input::Close | Input::Volume => self.bar[c].map(|b| match i {
                Input::Open => b.open,
                Input::High => b.high,
                Input::Low => b.low,
                Input::Close => b.close,
                _ => b.volume,
            }),
        }
    }

    /// Evaluate every node once for the listed coins at hour `hour`; unlisted coins get `None`.
    pub fn tick(&mut self, listed: &[bool], hour: i64) {
        self.hour = hour;
        for i in 0..self.prog.nodes.len() {
            if let Node::Op(Op::HoursSince, args) = &self.prog.nodes[i] {
                for c in 0..self.coins {
                    if listed[c] && self.vals[args[0]][c].is_some_and(|v| v != 0.0) {
                        self.since[i][c] = Some(hour);
                    }
                    self.vals[i][c] = if listed[c] { self.since[i][c].map(|t| ((hour - t) / HOUR) as f64) } else { None };
                }
                continue;
            }
            let node = &self.prog.nodes[i];
            if let Node::Op(op @ (Op::XsMean | Op::XsDemean | Op::XsRank), args) = node {
                let xs: Vec<(usize, f64)> =
                    (0..self.coins).filter(|&c| listed[c]).filter_map(|c| Some((c, self.vals[args[0]][c]?))).collect();
                let mut out = vec![None; self.coins];
                if !xs.is_empty() {
                    let mean = xs.iter().map(|(_, v)| v).sum::<f64>() / xs.len() as f64;
                    for &(c, v) in &xs {
                        out[c] = match op {
                            Op::XsMean => finite(mean),
                            Op::XsDemean => finite(v - mean),
                            _ => Some(rank(&xs, v)),
                        };
                    }
                }
                self.vals[i] = out;
                continue;
            }
            for c in 0..self.coins {
                let v = if listed[c] { self.eval(i, c) } else { None };
                let v = match &mut self.wins[i][c] {
                    Some(w) if listed[c] => w.push(v),
                    _ => v,
                };
                self.vals[i][c] = v.and_then(finite);
            }
        }
    }

    fn eval(&self, i: usize, c: usize) -> Option<f64> {
        let a = |k: usize| -> Option<f64> {
            match &self.prog.nodes[i] {
                Node::Op(_, args) => self.vals[args[k]][c],
                _ => None,
            }
        };
        let b = |x: bool| Some(if x { 1.0 } else { 0.0 });
        match &self.prog.nodes[i] {
            Node::Input(inp) => self.input(*inp, c),
            Node::Const(bits, _) => Some(f64::from_bits(*bits)),
            Node::Param(k) => Some(self.prog.params[*k].value),
            Node::Op(op, _) => match op {
                Op::Add => Some(a(0)? + a(1)?),
                Op::Sub => Some(a(0)? - a(1)?),
                Op::Mul => Some(a(0)? * a(1)?),
                Op::Div => {
                    let d = a(1)?;
                    if d == 0.0 { None } else { Some(a(0)? / d) }
                }
                Op::Min => Some(a(0)?.min(a(1)?)),
                Op::Max => Some(a(0)?.max(a(1)?)),
                Op::Neg => Some(-a(0)?),
                Op::Abs => Some(a(0)?.abs()),
                Op::Sign => {
                    let x = a(0)?;
                    Some(if x > 0.0 { 1.0 } else if x < 0.0 { -1.0 } else { 0.0 })
                }
                Op::Log => {
                    let x = a(0)?;
                    if x > 0.0 { Some(x.ln()) } else { None }
                }
                Op::Exp => Some(a(0)?.exp()),
                Op::Sqrt => {
                    let x = a(0)?;
                    if x >= 0.0 { Some(x.sqrt()) } else { None }
                }
                Op::Clip => Some(a(0)?.max(a(1)?).min(a(2)?)),
                Op::Gt => b(a(0)? > a(1)?),
                Op::Ge => b(a(0)? >= a(1)?),
                Op::Lt => b(a(0)? < a(1)?),
                Op::Le => b(a(0)? <= a(1)?),
                Op::And => {
                    let (x, y) = (a(0)?, a(1)?);
                    b(x != 0.0 && y != 0.0)
                }
                Op::Or => {
                    let (x, y) = (a(0)?, a(1)?);
                    b(x != 0.0 || y != 0.0)
                }
                Op::Not => b(a(0)? == 0.0),
                Op::If => {
                    if a(0)? != 0.0 { a(1) } else { a(2) }
                }
                Op::Convert(f) => Some(a(0)? * f64::from_bits(*f)),
                Op::Window(..) => a(0),
                Op::XsMean | Op::XsDemean | Op::XsRank | Op::HoursSince => unreachable!(),
            },
        }
    }

    pub fn weight(&self, c: usize) -> Option<f64> {
        self.vals[self.prog.weight][c]
    }

    /// A node's value for coin c at this tick.
    pub fn value(&self, node: usize, c: usize) -> Option<f64> {
        self.vals[node][c]
    }

    /// The prediction condition for coin c at this tick (None if absent or undefined).
    pub fn condition(&self, c: usize) -> Option<bool> {
        self.prog.prediction.and_then(|i| self.vals[i][c]).map(|v| v != 0.0)
    }
}

fn rank(xs: &[(usize, f64)], v: f64) -> f64 {
    if xs.len() == 1 {
        return 0.5;
    }
    let below = xs.iter().filter(|(_, x)| *x < v).count() as f64;
    let equal = xs.iter().filter(|(_, x)| *x == v).count() as f64;
    (below + (equal - 1.0) / 2.0) / (xs.len() as f64 - 1.0)
}
