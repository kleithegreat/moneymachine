//! Parser and type checker: JSON strategy -> hash-consed, typed expression DAG.

use crate::units::Unit;
use serde_json::{Map, Value};
use std::collections::HashMap;
use std::fmt;

pub const MAX_NODES: usize = 4096;
pub const MAX_DEPTH: usize = 64;
pub const MAX_HOURS: i64 = 4380;
const MAX_JSON_DEPTH: usize = 2 * MAX_DEPTH + 8;
const MAX_BYTES: usize = 1 << 20;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Code {
    Parse,
    UnknownInput,
    UnknownOp,
    Arity,
    Unit,
    Dimensionless,
    Bool,
    Window,
    Ref,
    Size,
}

impl Code {
    pub fn name(self) -> &'static str {
        match self {
            Code::Parse => "E_PARSE",
            Code::UnknownInput => "E_UNKNOWN_INPUT",
            Code::UnknownOp => "E_UNKNOWN_OP",
            Code::Arity => "E_ARITY",
            Code::Unit => "E_UNIT",
            Code::Dimensionless => "E_DIMENSIONLESS",
            Code::Bool => "E_BOOL",
            Code::Window => "E_WINDOW",
            Code::Ref => "E_REF",
            Code::Size => "E_SIZE",
        }
    }
}

#[derive(Debug, PartialEq)]
pub struct Reject {
    pub code: Code,
    pub path: String,
    pub msg: String,
}

impl fmt::Display for Reject {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{} at {}: {}", self.code.name(), self.path, self.msg)
    }
}

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Ty {
    Num(Unit),
    Bool,
}

/// Event inputs, as (DSL name, store dataset): hourly counts defined only at their own hour's tick
/// (DSL.md). An event input is declared here and nowhere else; the machine, the loader and the
/// simulator index event inputs by their row in this table.
pub const EVENT_INPUTS: [(&str, &str); 2] = [("forum_posts", "events_forum"), ("gov_proposals", "events_governance")];

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Input {
    Funding,
    Premium,
    Open,
    High,
    Low,
    Close,
    Volume,
    /// A row of EVENT_INPUTS.
    Event(usize),
}

/// Held inputs: (DSL name, input, unit). Each holds its latest delivered value.
const HELD: [(&str, Input, &str); 7] = [
    ("funding", Input::Funding, "1/h"),
    ("premium", Input::Premium, "1"),
    ("open", Input::Open, "usd/coin"),
    ("high", Input::High, "usd/coin"),
    ("low", Input::Low, "usd/coin"),
    ("close", Input::Close, "usd/coin"),
    ("volume", Input::Volume, "coin"),
];

impl Input {
    pub fn parse(name: &str) -> Option<Input> {
        HELD.iter()
            .find(|h| h.0 == name)
            .map(|h| h.1)
            .or_else(|| EVENT_INPUTS.iter().position(|e| e.0 == name).map(Input::Event))
    }

    pub fn name(self) -> &'static str {
        match self {
            Input::Event(slot) => EVENT_INPUTS[slot].0,
            held => HELD.iter().find(|h| h.1 == held).unwrap().0,
        }
    }

    /// The store dataset of an event input; None for held inputs.
    pub fn event_dataset(self) -> Option<&'static str> {
        match self {
            Input::Event(slot) => Some(EVENT_INPUTS[slot].1),
            _ => None,
        }
    }

    fn unit(self) -> Unit {
        Unit::parse(match self {
            Input::Event(_) => "ev",
            held => HELD.iter().find(|h| h.1 == held).unwrap().2,
        })
        .unwrap()
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Window {
    Lag,
    Mean,
    Sum,
    Std,
    MinOver,
    MaxOver,
    Ema,
}

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Op {
    Add,
    Sub,
    Mul,
    Div,
    Min,
    Max,
    Neg,
    Abs,
    Sign,
    Log,
    Exp,
    Sqrt,
    Clip,
    Gt,
    Ge,
    Lt,
    Le,
    And,
    Or,
    Not,
    If,
    /// Scale factor as raw bits, and the target unit: two converts are one node only if both agree.
    Convert(u64, Unit),
    Window(Window, u32),
    XsMean,
    XsDemean,
    XsRank,
    HoursSince,
}

const OPS: &[(&str, Op, usize)] = &[
    ("add", Op::Add, 2),
    ("sub", Op::Sub, 2),
    ("mul", Op::Mul, 2),
    ("div", Op::Div, 2),
    ("min", Op::Min, 2),
    ("max", Op::Max, 2),
    ("neg", Op::Neg, 1),
    ("abs", Op::Abs, 1),
    ("sign", Op::Sign, 1),
    ("log", Op::Log, 1),
    ("exp", Op::Exp, 1),
    ("sqrt", Op::Sqrt, 1),
    ("clip", Op::Clip, 3),
    ("gt", Op::Gt, 2),
    ("ge", Op::Ge, 2),
    ("lt", Op::Lt, 2),
    ("le", Op::Le, 2),
    ("and", Op::And, 2),
    ("or", Op::Or, 2),
    ("not", Op::Not, 1),
    ("if", Op::If, 3),
    ("convert", Op::Convert(0, Unit::ONE), 1),
    ("lag", Op::Window(Window::Lag, 0), 1),
    ("mean", Op::Window(Window::Mean, 0), 1),
    ("sum", Op::Window(Window::Sum, 0), 1),
    ("std", Op::Window(Window::Std, 0), 1),
    ("min_over", Op::Window(Window::MinOver, 0), 1),
    ("max_over", Op::Window(Window::MaxOver, 0), 1),
    ("ema", Op::Window(Window::Ema, 0), 1),
    ("xs_mean", Op::XsMean, 1),
    ("xs_demean", Op::XsDemean, 1),
    ("xs_rank", Op::XsRank, 1),
    ("hours_since", Op::HoursSince, 1),
];

#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub enum Node {
    Input(Input),
    /// Constant value as raw bits, with its unit.
    Const(u64, Unit),
    Param(usize),
    Op(Op, Vec<usize>),
}

#[derive(Debug)]
pub struct Param {
    pub name: String,
    pub value: f64,
    pub unit: Unit,
}

/// A checked program. Nodes are hash-consed and topologically ordered: args precede users.
#[derive(Debug)]
pub struct Program {
    pub nodes: Vec<Node>,
    pub types: Vec<Ty>,
    pub weight: usize,
    /// The pre-registered mechanism condition, a boolean node; not part of the strategy's identity.
    pub prediction: Option<usize>,
    pub params: Vec<Param>,
    /// Let names and their nodes, in declaration order.
    pub lets: Vec<(String, usize)>,
    pub mechanism: Value,
}

fn reject<T>(code: Code, path: &str, msg: impl Into<String>) -> Result<T, Reject> {
    Err(Reject { code, path: path.to_string(), msg: msg.into() })
}

fn json_depth(text: &str) -> usize {
    let (mut depth, mut max, mut in_str, mut esc) = (0usize, 0usize, false, false);
    for c in text.chars() {
        if in_str {
            match (esc, c) {
                (true, _) => esc = false,
                (false, '\\') => esc = true,
                (false, '"') => in_str = false,
                _ => {}
            }
            continue;
        }
        match c {
            '"' => in_str = true,
            '{' | '[' => {
                depth += 1;
                max = max.max(depth)
            }
            '}' | ']' => depth = depth.saturating_sub(1),
            _ => {}
        }
    }
    max
}

pub fn parse(text: &str) -> Result<Program, Reject> {
    if text.len() > MAX_BYTES || json_depth(text) > MAX_JSON_DEPTH {
        return reject(Code::Size, "$", "program too large or too deeply nested");
    }
    let v = serde_json::from_str::<Strict>(text).or_else(|e| reject(Code::Parse, "$", e.to_string()))?.0;
    Checker::default().program(&v)
}

/// JSON that rejects duplicate object keys, which parsers resolve differently.
struct Strict(Value);

impl<'de> serde::Deserialize<'de> for Strict {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        d.deserialize_any(StrictVisitor).map(Strict)
    }
}

struct StrictVisitor;

impl<'de> serde::de::Visitor<'de> for StrictVisitor {
    type Value = Value;

    fn expecting(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str("JSON")
    }
    fn visit_bool<E>(self, v: bool) -> Result<Value, E> {
        Ok(Value::Bool(v))
    }
    fn visit_i64<E>(self, v: i64) -> Result<Value, E> {
        Ok(Value::from(v))
    }
    fn visit_u64<E>(self, v: u64) -> Result<Value, E> {
        Ok(Value::from(v))
    }
    fn visit_f64<E>(self, v: f64) -> Result<Value, E> {
        Ok(Value::from(v))
    }
    fn visit_str<E>(self, v: &str) -> Result<Value, E> {
        Ok(Value::from(v))
    }
    fn visit_unit<E>(self) -> Result<Value, E> {
        Ok(Value::Null)
    }
    fn visit_seq<A: serde::de::SeqAccess<'de>>(self, mut a: A) -> Result<Value, A::Error> {
        let mut v = vec![];
        while let Some(Strict(x)) = a.next_element()? {
            v.push(x);
        }
        Ok(Value::Array(v))
    }
    fn visit_map<A: serde::de::MapAccess<'de>>(self, mut a: A) -> Result<Value, A::Error> {
        let mut m = Map::new();
        while let Some((k, Strict(x))) = a.next_entry::<String, Strict>()? {
            if m.insert(k.clone(), x).is_some() {
                return Err(serde::de::Error::custom(format!("duplicate key `{k}`")));
            }
        }
        Ok(Value::Object(m))
    }
}

#[derive(Default)]
struct Checker {
    nodes: Vec<Node>,
    types: Vec<Ty>,
    index: HashMap<Node, usize>,
    params: Vec<Param>,
    lets: Vec<(String, usize)>,
    parsed: usize,
}

fn fields<'a>(v: &'a Value, path: &str, required: &[&str], optional: &[&str]) -> Result<&'a Map<String, Value>, Reject> {
    let Some(m) = v.as_object() else { return reject(Code::Parse, path, "expected an object") };
    for k in m.keys() {
        if !required.contains(&k.as_str()) && !optional.contains(&k.as_str()) {
            return reject(Code::Parse, path, format!("unknown field `{k}`"));
        }
    }
    for k in required {
        if !m.contains_key(*k) {
            return reject(Code::Parse, path, format!("missing field `{k}`"));
        }
    }
    Ok(m)
}

fn string<'a>(v: &'a Value, path: &str) -> Result<&'a str, Reject> {
    v.as_str().map_or_else(|| reject(Code::Parse, path, "expected a string"), Ok)
}

fn number(v: &Value, path: &str) -> Result<f64, Reject> {
    v.as_f64().filter(|x| x.is_finite()).map_or_else(|| reject(Code::Parse, path, "expected a finite number"), Ok)
}

fn unit(v: &Value, path: &str) -> Result<Unit, Reject> {
    let s = string(v, path)?;
    Unit::parse(s).map_or_else(|| reject(Code::Unit, path, format!("bad unit `{s}`")), Ok)
}

impl Checker {
    fn program(mut self, v: &Value) -> Result<Program, Reject> {
        let m = fields(v, "$", &["dsl", "name", "mechanism", "weight"], &["params", "let", "prediction"])?;
        if m["dsl"] != Value::from(1) {
            return reject(Code::Parse, "$.dsl", "dsl must be 1");
        }
        string(&m["name"], "$.name")?;
        let mech = fields(&m["mechanism"], "$.mechanism", &["counterparty", "predictions", "capacity"], &[])?;
        string(&mech["counterparty"], "$.mechanism.counterparty")?;
        string(&mech["capacity"], "$.mechanism.capacity")?;
        match mech["predictions"].as_array() {
            Some(a) if a.iter().all(Value::is_string) => {}
            _ => return reject(Code::Parse, "$.mechanism.predictions", "expected a list of strings"),
        }
        if let Some(p) = m.get("params") {
            let Some(p) = p.as_object() else { return reject(Code::Parse, "$.params", "expected an object") };
            for (name, spec) in p {
                let path = format!("$.params.{name}");
                let s = fields(spec, &path, &["value", "unit"], &[])?;
                self.params.push(Param {
                    name: name.clone(),
                    value: number(&s["value"], &path)?,
                    unit: unit(&s["unit"], &path)?,
                });
            }
        }
        if let Some(l) = m.get("let") {
            let Some(l) = l.as_object() else { return reject(Code::Parse, "$.let", "expected an object") };
            for (name, e) in l {
                let i = self.expr(e, &format!("$.let.{name}"), 1)?;
                self.lets.push((name.clone(), i));
            }
        }
        let w = self.expr(&m["weight"], "$.weight", 1)?;
        match self.types[w] {
            Ty::Num(u) if u == Unit::ONE => {}
            Ty::Num(u) => return reject(Code::Dimensionless, "$.weight", format!("weight has unit {u}, needs 1")),
            Ty::Bool => return reject(Code::Bool, "$.weight", "weight is boolean"),
        }
        let prediction = match m.get("prediction") {
            None => None,
            Some(p) => {
                let p = fields(p, "$.prediction", &["condition"], &[])?;
                let c = self.expr(&p["condition"], "$.prediction.condition", 1)?;
                if self.types[c] != Ty::Bool {
                    return reject(Code::Bool, "$.prediction.condition", "condition must be boolean");
                }
                Some(c)
            }
        };
        Ok(Program {
            nodes: self.nodes,
            types: self.types,
            weight: w,
            prediction,
            params: self.params,
            lets: self.lets,
            mechanism: m["mechanism"].clone(),
        })
    }

    fn intern(&mut self, n: Node, t: Ty) -> usize {
        if let Some(&i) = self.index.get(&n) {
            return i;
        }
        self.nodes.push(n.clone());
        self.types.push(t);
        self.index.insert(n, self.nodes.len() - 1);
        self.nodes.len() - 1
    }

    fn expr(&mut self, v: &Value, path: &str, depth: usize) -> Result<usize, Reject> {
        self.parsed += 1;
        if depth > MAX_DEPTH || self.parsed > MAX_NODES {
            return reject(Code::Size, path, "program too large or too deeply nested");
        }
        let Some(m) = v.as_object() else { return reject(Code::Parse, path, "expected an expression object") };
        if m.contains_key("input") {
            let m = fields(v, path, &["input"], &[])?;
            let name = string(&m["input"], path)?;
            let Some(inp) = Input::parse(name) else {
                return reject(Code::UnknownInput, path, format!("unknown input `{name}`"));
            };
            return Ok(self.intern(Node::Input(inp), Ty::Num(inp.unit())));
        }
        if m.contains_key("const") {
            let m = fields(v, path, &["const", "unit"], &[])?;
            let x = number(&m["const"], path)?;
            let u = unit(&m["unit"], path)?;
            return Ok(self.intern(Node::Const((x + 0.0).to_bits(), u), Ty::Num(u)));
        }
        if m.contains_key("param") {
            let m = fields(v, path, &["param"], &[])?;
            let name = string(&m["param"], path)?;
            let Some(k) = self.params.iter().position(|p| p.name == name) else {
                return reject(Code::Ref, path, format!("undefined param `{name}`"));
            };
            return Ok(self.intern(Node::Param(k), Ty::Num(self.params[k].unit)));
        }
        if m.contains_key("ref") {
            let m = fields(v, path, &["ref"], &[])?;
            let name = string(&m["ref"], path)?;
            return match self.lets.iter().find(|(n, _)| n == name) {
                Some((_, i)) => Ok(*i),
                None => reject(Code::Ref, path, format!("`{name}` is not an earlier let")),
            };
        }
        if !m.contains_key("op") {
            return reject(Code::Parse, path, "expression needs one of input, const, param, ref, op");
        }
        let name = string(&m["op"], path)?;
        let Some(&(_, op, arity)) = OPS.iter().find(|(n, _, _)| *n == name) else {
            return reject(Code::UnknownOp, path, format!("unknown op `{name}`"));
        };
        let extra: &[&str] = match op {
            Op::Window(..) => &["hours"],
            Op::Convert(..) => &["to"],
            _ => &[],
        };
        let m = fields(v, path, &[&["op", "args"][..], extra].concat(), &[])?;
        let Some(args) = m["args"].as_array() else { return reject(Code::Parse, path, "args must be a list") };
        if args.len() != arity {
            return reject(Code::Arity, path, format!("`{name}` takes {arity} args, got {}", args.len()));
        }
        let mut ix = Vec::with_capacity(arity);
        for (k, a) in args.iter().enumerate() {
            ix.push(self.expr(a, &format!("{path}.args[{k}]"), depth + 1)?);
        }
        let ts: Vec<Ty> = ix.iter().map(|&i| self.types[i]).collect();
        let (op, ty) = self.type_op(op, name, &ts, m, path)?;
        Ok(self.intern(Node::Op(op, ix), ty))
    }

    fn type_op(&self, op: Op, name: &str, ts: &[Ty], m: &Map<String, Value>, path: &str) -> Result<(Op, Ty), Reject> {
        let num = |k: usize| match ts[k] {
            Ty::Num(u) => Ok(u),
            Ty::Bool => reject(Code::Bool, path, format!("`{name}` arg {k} is boolean")),
        };
        let boolean = |k: usize| match ts[k] {
            Ty::Bool => Ok(()),
            Ty::Num(_) => reject(Code::Bool, path, format!("`{name}` arg {k} must be boolean")),
        };
        let same = |a: Unit, b: Unit| {
            if a == b { Ok(a) } else { reject(Code::Unit, path, format!("`{name}` mixes {a} and {b}")) }
        };
        let one = |u: Unit| {
            if u == Unit::ONE { Ok(u) } else { reject(Code::Dimensionless, path, format!("`{name}` needs unit 1, got {u}")) }
        };
        let ty = match op {
            Op::Add | Op::Sub | Op::Min | Op::Max => Ty::Num(same(num(0)?, num(1)?)?),
            Op::Mul => Ty::Num(num(0)?.mul(num(1)?).map_or_else(|| reject(Code::Unit, path, "exponent overflow"), Ok)?),
            Op::Div => Ty::Num(num(0)?.div(num(1)?).map_or_else(|| reject(Code::Unit, path, "exponent overflow"), Ok)?),
            Op::Neg | Op::Abs => Ty::Num(num(0)?),
            Op::Sign => {
                num(0)?;
                Ty::Num(Unit::ONE)
            }
            Op::Log | Op::Exp => Ty::Num(one(num(0)?)?),
            Op::Sqrt => Ty::Num(num(0)?.sqrt().map_or_else(|| reject(Code::Unit, path, "sqrt needs even exponents"), Ok)?),
            Op::Clip => Ty::Num(same(same(num(0)?, num(1)?)?, num(2)?)?),
            Op::Gt | Op::Ge | Op::Lt | Op::Le => {
                same(num(0)?, num(1)?)?;
                Ty::Bool
            }
            Op::And | Op::Or => {
                boolean(0)?;
                boolean(1)?;
                Ty::Bool
            }
            Op::Not => {
                boolean(0)?;
                Ty::Bool
            }
            Op::If => {
                boolean(0)?;
                match (ts[1], ts[2]) {
                    (Ty::Bool, Ty::Bool) => Ty::Bool,
                    (Ty::Num(a), Ty::Num(b)) => Ty::Num(same(a, b)?),
                    _ => return reject(Code::Bool, path, "`if` branches differ in kind"),
                }
            }
            Op::Convert(..) => {
                let to = unit(&m["to"], path)?;
                let from = num(0)?;
                let Some(f) = from.conversion(to) else {
                    return reject(Code::Unit, path, format!("cannot convert {from} to {to}"));
                };
                return Ok((Op::Convert(f.to_bits(), to), Ty::Num(to)));
            }
            Op::Window(w, _) => {
                let u = num(0)?;
                let Some(h) = m["hours"].as_i64().filter(|h| (1..=MAX_HOURS).contains(h)) else {
                    return reject(Code::Window, path, format!("hours must be an integer in 1..={MAX_HOURS}"));
                };
                return Ok((Op::Window(w, h as u32), Ty::Num(u)));
            }
            Op::HoursSince => {
                boolean(0)?;
                Ty::Num(Unit::base("h").unwrap())
            }
            Op::XsMean | Op::XsDemean => Ty::Num(num(0)?),
            Op::XsRank => Ty::Num(one(num(0)?)?),
        };
        Ok((op, ty))
    }
}

impl Program {
    /// Canonical text of the strategy: the DAG reachable from `weight` in post-order, with
    /// params by name and unit. Let names, declaration order and dead lets do not matter.
    pub fn canonical(&self) -> String {
        let mut order: Vec<usize> = vec![];
        let mut seen = vec![false; self.nodes.len()];
        fn visit(p: &Program, i: usize, seen: &mut Vec<bool>, order: &mut Vec<usize>) {
            if seen[i] {
                return;
            }
            seen[i] = true;
            if let Node::Op(_, args) = &p.nodes[i] {
                for &a in args {
                    visit(p, a, seen, order);
                }
            }
            order.push(i);
        }
        visit(self, self.weight, &mut seen, &mut order);
        let pos: HashMap<usize, usize> = order.iter().enumerate().map(|(k, &i)| (i, k)).collect();
        let lines: Vec<String> = order
            .iter()
            .map(|&i| match &self.nodes[i] {
                Node::Input(inp) => format!("input {}", inp.name()),
                Node::Const(bits, u) => format!("const {:?} {u}", f64::from_bits(*bits)),
                Node::Param(k) => format!("param {} {}", self.params[*k].name, self.params[*k].unit),
                Node::Op(op, args) => {
                    let a: Vec<String> = args.iter().map(|x| pos[x].to_string()).collect();
                    let op = match op {
                        Op::Convert(f, to) => format!("Convert({:?} {to})", f64::from_bits(*f)),
                        other => format!("{other:?}"),
                    };
                    format!("{op} {}", a.join(" "))
                }
            })
            .collect();
        lines.join("\n")
    }

    /// Params actually used by the canonical form, as (name, value), sorted by name.
    pub fn param_values(&self) -> Vec<(String, f64)> {
        let canon = self.canonical();
        let mut v: Vec<(String, f64)> = self
            .params
            .iter()
            .filter(|p| canon.lines().any(|l| l.starts_with(&format!("param {} ", p.name))))
            .map(|p| (p.name.clone(), p.value))
            .collect();
        v.sort_by(|a, b| a.0.cmp(&b.0));
        v
    }
}

impl Program {
    /// Event datasets this program reads (for R_INPUT_UNAVAILABLE).
    pub fn event_datasets(&self) -> Vec<&'static str> {
        let mut v: Vec<&'static str> =
            self.nodes.iter().filter_map(|n| if let Node::Input(i) = n { i.event_dataset() } else { None }).collect();
        v.sort();
        v.dedup();
        v
    }
}
