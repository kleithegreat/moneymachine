//! The equivalence key (kernel/CANONICAL.md): equality saturation over the exact rule set R,
//! then extraction of the smallest term with a total-order tie-break.

use crate::dsl::{Input, Node, Op, Program, Window};
use crate::market::sha256_hex;
use egg::{rewrite as rw, CostFunction, EGraph, Extractor, Id, RecExpr, Rewrite, Runner, SymbolLang};
use std::time::Duration;

pub const R_VERSION: &str = "R1";
const ITER_LIMIT: usize = 30;
const NODE_LIMIT: usize = 20_000;
const ZERO: &str = "const/0000000000000000/";

fn op_symbol(op: &Op) -> String {
    match op {
        Op::Convert(f, to) => format!("convert/{f:016x}/{to}"),
        Op::Window(w, h) => {
            let name = match w {
                Window::Lag => "lag",
                Window::Mean => "mean",
                Window::Sum => "sum",
                Window::Std => "std",
                Window::MinOver => "min_over",
                Window::MaxOver => "max_over",
                Window::Ema => "ema",
            };
            format!("{name}/{h}")
        }
        other => match other {
            Op::Add => "add",
            Op::Sub => "sub",
            Op::Mul => "mul",
            Op::Div => "div",
            Op::Min => "min",
            Op::Max => "max",
            Op::Neg => "neg",
            Op::Abs => "abs",
            Op::Sign => "sign",
            Op::Log => "log",
            Op::Exp => "exp",
            Op::Sqrt => "sqrt",
            Op::Clip => "clip",
            Op::Gt => "gt",
            Op::Ge => "ge",
            Op::Lt => "lt",
            Op::Le => "le",
            Op::And => "and",
            Op::Or => "or",
            Op::Not => "not",
            Op::If => "if",
            Op::XsMean => "xs_mean",
            Op::XsDemean => "xs_demean",
            Op::XsRank => "xs_rank",
            Op::HoursSince => "hours_since",
            Op::Convert(..) | Op::Window(..) => unreachable!(),
        }
        .to_string(),
    }
}

/// The weight DAG as an egg term.
pub fn term(p: &Program) -> RecExpr<SymbolLang> {
    let mut expr = RecExpr::default();
    let mut ids: Vec<Option<Id>> = vec![None; p.nodes.len()];
    fn add(p: &Program, i: usize, expr: &mut RecExpr<SymbolLang>, ids: &mut Vec<Option<Id>>) -> Id {
        if let Some(id) = ids[i] {
            return id;
        }
        let node = match &p.nodes[i] {
            Node::Input(inp) => SymbolLang::leaf(format!("input/{}", Input::name(*inp))),
            Node::Const(bits, u) => SymbolLang::leaf(format!("const/{bits:016x}/{u}")),
            Node::Param(k) => SymbolLang::leaf(format!("param/{}/{}", p.params[*k].name, p.params[*k].unit)),
            Node::Op(op, args) => {
                let children = args.iter().map(|&a| add(p, a, expr, ids)).collect();
                SymbolLang::new(op_symbol(op), children)
            }
        };
        let id = expr.add(node);
        ids[i] = Some(id);
        id
    }
    add(p, p.weight, &mut expr, &mut ids);
    expr
}

fn is_plus_zero(var: &'static str) -> impl Fn(&mut EGraph<SymbolLang, ()>, Id, &egg::Subst) -> bool {
    let v: egg::Var = var.parse().unwrap();
    move |g, _, subst| g[subst[v]].nodes.iter().any(|n| n.children.is_empty() && n.op.as_str().starts_with(ZERO))
}

pub fn rules() -> Vec<Rewrite<SymbolLang, ()>> {
    let one = "const/3ff0000000000000/1";
    vec![
        rw!("neg-neg"; "(neg (neg ?x))" => "?x"),
        rw!("abs-abs"; "(abs (abs ?x))" => "(abs ?x)"),
        rw!("abs-neg"; "(abs (neg ?x))" => "(abs ?x)"),
        rw!("mul-one"; {format!("(mul ?x {one})").parse::<egg::Pattern<SymbolLang>>().unwrap()} => "?x"),
        rw!("div-one"; {format!("(div ?x {one})").parse::<egg::Pattern<SymbolLang>>().unwrap()} => "?x"),
        rw!("sub-zero"; "(sub ?x ?z)" => "?x" if is_plus_zero("?z")),
        rw!("add-comm"; "(add ?a ?b)" => "(add ?b ?a)"),
        rw!("mul-comm"; "(mul ?a ?b)" => "(mul ?b ?a)"),
        rw!("and-comm"; "(and ?a ?b)" => "(and ?b ?a)"),
        rw!("or-comm"; "(or ?a ?b)" => "(or ?b ?a)"),
        rw!("not-not"; "(not (not ?c))" => "?c"),
        rw!("if-not"; "(if (not ?c) ?a ?b)" => "(if ?c ?b ?a)"),
        rw!("gt-lt"; "(gt ?a ?b)" => "(lt ?b ?a)"),
        rw!("lt-gt"; "(lt ?a ?b)" => "(gt ?b ?a)"),
        rw!("ge-le"; "(ge ?a ?b)" => "(le ?b ?a)"),
        rw!("le-ge"; "(le ?a ?b)" => "(ge ?b ?a)"),
    ]
}

/// Fewest nodes, ties broken by the serialization.
struct SizeThenText;

impl CostFunction<SymbolLang> for SizeThenText {
    type Cost = (usize, String);

    fn cost<C>(&mut self, enode: &SymbolLang, mut costs: C) -> Self::Cost
    where
        C: FnMut(Id) -> Self::Cost,
    {
        let kids: Vec<Self::Cost> = enode.children.iter().map(|&c| costs(c)).collect();
        let size = 1 + kids.iter().map(|k| k.0).sum::<usize>();
        let text = if kids.is_empty() {
            enode.op.to_string()
        } else {
            format!("({} {})", enode.op, kids.iter().map(|k| k.1.as_str()).collect::<Vec<_>>().join(" "))
        };
        (size, text)
    }
}

/// The extracted canonical term of a program's weight.
pub fn canonical_term(p: &Program) -> String {
    let runner = Runner::default()
        .with_iter_limit(ITER_LIMIT)
        .with_node_limit(NODE_LIMIT)
        .with_time_limit(Duration::from_secs(u32::MAX as u64))
        .with_expr(&term(p))
        .run(&rules());
    let root = runner.roots[0];
    Extractor::new(&runner.egraph, SizeThenText).find_best(root).0 .1
}

pub fn equivalence_key(p: &Program) -> String {
    sha256_hex(format!("{R_VERSION}\n{}", canonical_term(p)).as_bytes())
}
