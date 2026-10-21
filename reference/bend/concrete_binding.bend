import Base

type Abort is Data:
  Unavailable{}
  Causality{}

type Res is Data:
  Err{e: Abort}
  Ok{v: Nat}

def mem(+x: Nat, +xs: +List<Nat>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      Bool.or(Nat.is_eq(x, h), mem(x, t))

def all_bound(+slots: +List<Nat>, +bound: +List<Nat>) -> Bool:
  match slots:
    case Nil{}:
      True{}
    case Con{h, t}:
      Bool.and(mem(h, bound), all_bound(t, bound))

def step(r: Res, +k: Nat) -> Res:
  match r:
    case Err{e}:
      Err{e}
    case Ok{v}:
      match k:
        case 0n:
          Err{Causality{}}
        case 1n+p:
          Ok{Nat.add(v, p)}

def steps(+ks: +List<Nat>, r: Res) -> Res:
  match ks:
    case Nil{}:
      r
    case Con{h, t}:
      steps(t, step(r, h))

def start(b: Bool) -> Res:
  match b:
    case False{}:
      Err{Unavailable{}}
    case True{}:
      Ok{0n}

def run(+slots: +List<Nat>, +bound: +List<Nat>, +ks: +List<Nat>) -> Res:
  steps(ks, start(all_bound(slots, bound)))

def is_unavailable(r: Res) -> Bool:
  match r:
    case Err{e}:
      match e:
        case Unavailable{}:
          True{}
        case Causality{}:
          False{}
    case Ok{v}:
      False{}

law step_keep:
  for +r: Res
  for +k: Nat
  {is_unavailable(step(r, k)) == is_unavailable(r) : Bool}

def step_keep(r, k):
  match r:
    case Err{e}:
      {==}
    case Ok{v}:
      match k:
        case 0n:
          {==}
        case 1n+p:
          {==}

law steps_keep:
  for +ks: +List<Nat>
  for +r: Res
  {is_unavailable(steps(ks, r)) == is_unavailable(r) : Bool}

def steps_keep(ks, r):
  match ks:
    case Nil{}:
      {==}
    case Con{h, t}:
      Equal.trans(Bool, is_unavailable(steps(t, step(r, h))), is_unavailable(step(r, h)), is_unavailable(r),
        steps_keep(t, step(r, h)), step_keep(r, h))

law start_avail:
  for +b: Bool
  {is_unavailable(start(b)) == Bool.not(b) : Bool}

def start_avail(b):
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

law binding:
  for +slots: +List<Nat>
  for +bound: +List<Nat>
  for +ks: +List<Nat>
  {is_unavailable(run(slots, bound, ks)) == Bool.not(all_bound(slots, bound)) : Bool}

def binding(slots, bound, ks):
  Equal.trans(Bool, is_unavailable(steps(ks, start(all_bound(slots, bound)))),
    is_unavailable(start(all_bound(slots, bound))), Bool.not(all_bound(slots, bound)),
    steps_keep(ks, start(all_bound(slots, bound))), start_avail(all_bound(slots, bound)))
