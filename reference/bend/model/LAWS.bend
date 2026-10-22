import Base
import ./num.bend as N
import ./machine.bend as M
import ./sim.bend as S

# The frozen laws L1, L4 and L5 (reference/lean/Ref/Laws.lean), stated over the Bend model of the same
# definitions and the concrete exact number type of num.bend.

def unav(+r: S.SRes) -> Bool:
  match r:
    case S.SErr{a}:
      match a:
        case S.InputUnavailable{}:
          True{}
        case _:
          False{}
    case S.SOk{s}:
      False{}

def run_unav(+r: S.RunRes) -> Bool:
  match r:
    case S.RErr{a}:
      match a:
        case S.InputUnavailable{}:
          True{}
        case _:
          False{}
    case S.ROk{x}:
      False{}

# L5, binding: a run is refused as unavailable exactly when some event source the program names is unbound.
law L5_binding:
  for +p: M.Program
  for +m: S.Market
  for +v: S.Venue
  for +pol: S.Policy
  for +stop: N.Z
  {run_unav(S.run(p, m, v, pol, stop)) == Bool.not(S.bound(S.make(p, m, v, pol, stop))) : Bool}

# L5, preflight: before any delivery or tick, an unbound source refuses the run; with every source bound,
# preflight passes and the run starts with the ordinary first delivery and tick.
law L5_preflight:
  for +c: S.Ctx
  {S.start(c) == Bool.pick(S.SRes, S.bound(c),
    S.ticked(c, S.pol_start(S.ctx_pol(c)), S.deliver(c, S.state0(c), N.zadd(S.pol_start(S.ctx_pol(c)), S.pol_delta(S.ctx_pol(c))))),
    S.SErr{S.InputUnavailable{}}) : S.SRes}
