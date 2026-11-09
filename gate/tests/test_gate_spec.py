"""Source-blind statistical contracts from whitepaper §8, NULLS.md and criteria.

The dated stage-2 revisions define the screen used by stages 3/4.  Selection
statistics are not inferential p-values after adaptive search.  All markets and
ledgers here are synthetic; no fitted parameters, stores or campaign evidence
are loaded.  Only production signatures/docstrings were inspected.

Assumptions: C4.5 v3's 'not established' is its named residual class; invalid
Holm probabilities, invalid bootstrap dimensions/parameters, and nonfinite total
returns have no specified API policy, so no rejection policy is invented here.

Reachability: the three extreme-float betting xfails check mathematical/API
conformance, not campaign outcomes (criteria's 2026-10-27 19:02 revision states
kernel returns are bounded far below overflow). The two N3 xfails witness one
campaign-reachable distribution defect: truncation is not clipping. It changes
market paths and calibration, but preserves symmetry and is not itself evidence
of excess false promotions. C4.5 v3 uses N2, so this N3 defect does not affect it.
"""

import io
import itertools
import json
import math
import sqlite3
from concurrent.futures import ThreadPoolExecutor
from fractions import Fraction
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pandas as pd
import pytest
from scipy.special import betainc
from scipy.stats import binom, norm

from gate import gate, markets
from gate.agent import campaigns, daemon


@pytest.mark.parametrize("n", [1, 2, 17, 400])
@pytest.mark.parametrize("sign", [-1, 0, 1])
def test_dsr_hand_moments(n, sign) -> None:
    """r=sign+(-1,0,1): s=1, skew=0, ordinary kurtosis=3/2.

    Thus S=sign, V=1+sign²/8 and z=(sign*sqrt(2)-Z_N)/sqrt(V).
    This distinguishes sample sd, population moments, ordinary kurtosis and the
    revised null spread from the retired cross-trial-spread benchmark.
    """
    gamma = 0.5772156649015328606
    z_n = 0 if n == 1 else ((1 - gamma) * norm.ppf(1 - 1 / n) + gamma * norm.ppf(1 - 1 / (n * math.e)))
    expected = norm.cdf((sign * math.sqrt(2) - z_n) / math.sqrt(1 + sign**2 / 8))
    assert gate.dsr(np.array([-1.0, 0.0, 1.0]) + sign, n) == pytest.approx(expected, abs=2e-14)


@pytest.mark.parametrize("r", [[], [1], [1, 2], [0, 0, 0], [3, 3, 3]])
def test_dsr_short_or_constant(r) -> None:
    """Criteria 2026-10-27 18:43: T<3 or sd=0 gives score 0."""
    assert gate.dsr(r, 1) == 0


@pytest.mark.parametrize("offset, expected", [(0.0, 0.0), (1e-7, 0.0), (1e-4, 1.0)])
def test_dsr_degenerate_variance(offset, expected) -> None:
    """Three a's and one a+1 have sd=1/2, skew=2/sqrt(3), kurt=7/3.

    At a=sqrt(3)/2-1/4, S=sqrt(3), V=(1-S/sqrt(3))²=0.
    Adding d makes V=4d²/3; the 1e-12 relative rule still excludes d=1e-7
    (V=1.33e-14, cutoff approximately 4e-12), but not d=1e-4.
    """
    a = math.sqrt(3) / 2 - 1 / 4 + offset
    assert gate.dsr([a, a, a, a + 1], 1) == expected


@pytest.mark.parametrize("scale", [1e-300, 1.0, 1e300])
def test_dsr_finite_rescaling(scale) -> None:
    """The 19:02 revision requires positive-scale invariance, even near overflow."""
    assert gate.dsr(np.array([0.0, 1.0, 2.0]) * scale, 1) == pytest.approx(norm.cdf(4 / 3))


@pytest.mark.parametrize("bad", [np.nan, np.inf, -np.inf])
@pytest.mark.parametrize("prefix", [[], [0.0], [0.0, 1.0, 2.0]])
def test_dsr_nonfinite_is_failure_even_when_short(bad, prefix) -> None:
    """The 18:50 revision says any nonfinite return raises, never score zero."""
    with pytest.raises(ValueError):
        gate.dsr(prefix + [bad], 1)


@pytest.fixture
def ledger(tmp_path: Path):
    """Minimal in-memory-generated SQL wire fixture, not a production ledger."""
    path = tmp_path / "synthetic.sqlite"
    with sqlite3.connect(path) as db:
        db.executescript("""
            CREATE TABLE experiments
              (id INTEGER, campaign TEXT, agent TEXT, trial TEXT, mode TEXT, program TEXT);
            CREATE TABLE results (experiment_id INTEGER, returns BLOB, summary TEXT);
            CREATE TABLE disclosures
              (id INTEGER, campaign TEXT, agent TEXT, kind TEXT, content TEXT);
        """)
    return path


def add_trial(
    ledger, key, returns, fills: int = 1, agent: str = "A", campaign: str = "spec", mode: str = "search"
) -> None:
    with sqlite3.connect(ledger) as db:
        number = db.execute("SELECT count(*)+1 FROM experiments").fetchone()[0]
        db.execute(
            "INSERT INTO experiments VALUES (?,?,?,?,?,?)",
            (number, campaign, agent, key, mode, json.dumps({"label": key})),
        )
        db.execute(
            "INSERT INTO results VALUES (?,?,?)",
            (number, np.asarray(returns, dtype=np.float64).tobytes(), json.dumps({"fills": fills})),
        )


def test_trial_count_is_not_evaluation_budget(ledger) -> None:
    """Stage 3 counts duplicate/zero-fill evals in budget; N counts distinct filled trials."""
    add_trial(ledger, "same", [0.0, 1.0, 2.0])
    add_trial(ledger, "same", [0.0, 1.0, 2.0])
    add_trial(ledger, "flat", [0.0, 0.0, 0.0], fills=0)
    add_trial(ledger, "other-arm", [1.0, 2.0, 3.0], agent="B")
    add_trial(ledger, "holdout", [1.0, 2.0, 3.0], mode="holdout")
    add_trial(ledger, "other-campaign", [1.0, 2.0, 3.0], campaign="elsewhere")
    assert set(gate.trials(ledger, "spec", "A")) == {"same"}
    assert set(gate.trials(ledger, "spec")) == {"same", "other-arm"}


def test_evaluation_ledger_counts_rejections_and_duplicates_not_checks(ledger) -> None:
    """C3.1/Swarm accounting: 2 identical evals + rejection + abort = 4.
    A check's path-bearing rejection and non-evaluation disclosures are free.
    Campaign/agent filtering prevents spending another arm's budget.
    """
    rows = [
        ("spec", "A", "eval", {"fills": 0}),
        ("spec", "A", "eval", {"fills": 0}),
        ("spec", "A", "reject", {"code": "TYPE"}),
        ("spec", "A", "abort", {"code": "R_BOUND"}),
        ("spec", "A", "reject", {"code": "TYPE", "path": "-"}),
        ("spec", "A", "history", {}),
        ("spec", "B", "eval", {"fills": 1}),
        ("other", "A", "eval", {"fills": 1}),
    ]
    with sqlite3.connect(ledger) as db:
        for number, (campaign, agent, kind, content) in enumerate(rows):
            db.execute(
                "INSERT INTO disclosures VALUES (?,?,?,?,?)", (number, campaign, agent, kind, json.dumps(content))
            )
    assert campaigns.evaluations(ledger, "spec", "A") == 4
    assert campaigns.evaluations(ledger, "spec", "B") == 1
    assert campaigns.evaluations(ledger, "empty", "A") == 0


def test_empty_search_never_selects(ledger) -> None:
    finalists, report = gate.search_decision(ledger, "spec")
    assert finalists == []
    assert report["n"] == 0
    assert report["spa_p"] is None


@pytest.mark.parametrize("spa_p, selected", [(0.049, True), (0.05, True), (0.051, False)])
def test_spa_consistent_pvalue_and_bootstrap_contract(monkeypatch: pytest.MonkeyPatch, ledger, spa_p, selected) -> None:
    """Criteria: flat benchmark, losses=-returns, all trials, consistent p,
    studentization, stationary blocks of 6, 1000 replicates and id-derived seed.
    The three reported SPA variants deliberately imply different decisions.
    """
    returns = np.array([0.02, 0.03] * 30)
    add_trial(ledger, "winner", returns)
    add_trial(ledger, "loser", -returns)
    calls = []

    class SPA:
        def __init__(self, benchmark, models, **kwargs) -> None:
            calls.append((np.asarray(benchmark), np.asarray(models), kwargs))
            self.pvalues = pd.Series({"lower": 0.0, "consistent": spa_p, "upper": 1.0})

        def compute(self) -> None:
            pass

    monkeypatch.setattr(gate, "SPA", SPA)
    monkeypatch.setattr(gate, "stepm", lambda r, screened, seed: list(screened))
    finalists, _ = gate.search_decision(ledger, "spec")
    assert ("winner" in finalists) is selected
    assert "loser" not in finalists
    benchmark, models, options = calls[0]
    np.testing.assert_array_equal(benchmark, np.zeros(60))
    assert {tuple(models[:, i]) for i in range(2)} == {tuple(returns), tuple(-returns)}
    assert options["block_size"] == 6
    assert options["reps"] == 1000
    assert options.get("studentize", True) is True
    assert options.get("bootstrap", "stationary") in ("stationary", "sb")
    first_seed = options["seed"]
    gate.search_decision(ledger, "spec")
    assert calls[-1][2]["seed"] == first_seed
    add_trial(ledger, "winner", returns, campaign="another-id")
    gate.search_decision(ledger, "another-id")
    assert calls[-1][2]["seed"] != first_seed


def test_screen_threshold_inclusive_and_raw_n_controls_selection(monkeypatch: pytest.MonkeyPatch, ledger) -> None:
    """DSR>=.95 includes equality; a clustered N=1 cannot replace raw N=2.
    Both series are perfectly correlated but distinct trials, so diagnostics
    also exercise recomputing the screen at the smaller cluster counts.
    """
    add_trial(ledger, "boundary", [0.01, 0.02] * 30)
    add_trial(ledger, "below", [0.02, 0.04] * 30)

    class SPA:
        def __init__(self, *args, **kwargs) -> None:
            self.pvalues = pd.Series({"consistent": 0.0})

        def compute(self) -> None:
            pass

    monkeypatch.setattr(gate, "SPA", SPA)
    monkeypatch.setattr(gate, "stepm", lambda r, screened, seed: list(screened))
    monkeypatch.setattr(gate, "dsr", lambda r, n: 0.95 if r[0] == 0.01 else np.nextafter(0.95, 0))
    finalists, report = gate.search_decision(ledger, "spec")
    assert finalists == ["boundary"]
    assert report["n"] == 2
    monkeypatch.setattr(gate, "dsr", lambda r, n: 0.96 if n == 1 else 0.94)
    finalists, _ = gate.search_decision(ledger, "spec")
    assert finalists == []


def test_stepm_subset_and_parameters(monkeypatch: pytest.MonkeyPatch) -> None:
    """StepM sees only screened columns; returned indices map back to trial keys."""
    r = pd.DataFrame({"a": [2.0, 3.0] * 8, "omit": [-3.0, -2.0] * 8, "b": [3.0, 2.0] * 8})

    class StepM:
        def __init__(self, benchmark, models, **kwargs) -> None:
            np.testing.assert_array_equal(benchmark, np.zeros(16))
            np.testing.assert_array_equal(models, -r[["b", "a"]])
            assert kwargs["block_size"] == 6
            assert kwargs["reps"] == 1000
            assert kwargs["size"] == 0.05
            assert kwargs["seed"] == 71
            assert kwargs.get("studentize", True) is True
            assert kwargs.get("bootstrap", "stationary") in ("stationary", "sb")
            self.superior_models = ["a"]

        def compute(self) -> None:
            pass

    monkeypatch.setattr(gate, "StepM", StepM)
    assert gate.stepm(r, ["b", "a"], 71) == ["a"]
    assert gate.stepm(r, [], 71) == []


def test_spa_and_stepm_separated_supports(ledger) -> None:
    """Returns in [2,3] have mean>=2; centered bootstrap means are at most 1.

    Thus their observed statistic exceeds every resampled statistic: SPA p=0.
    Its negative has no positive effect and StepM cannot select it.  Repeated
    identical winners exercise correlated/tied hypotheses without splitting N.
    """
    r = pd.DataFrame({"a": [2.0, 3.0] * 30, "b": [-2.0, -3.0] * 30, "tie": [2.0, 3.0] * 30})
    for key in r:
        add_trial(ledger, key, r[key])
    finalists, report = gate.search_decision(ledger, "spec")
    assert report["spa_p"] == 0
    assert set(finalists) == {"a", "tie"}
    assert set(gate.stepm(r, list(r), 91)) == {"a", "tie"}


@pytest.mark.parametrize("threshold", [0.5, 0.9])
def test_effective_n_absolute_correlation_and_constants(threshold) -> None:
    """Stage 4: |rho| clusters sign reversals; zero-variance trials are singletons."""
    x = np.array([-1.0, -1.0, 1.0, 1.0])
    y = np.array([-1.0, 1.0, -1.0, 1.0])
    r = pd.DataFrame({"x": x, "same": x, "opposite": -x, "orthogonal": y, "zero": np.zeros(4), "constant": np.ones(4)})
    labels = gate.cluster_labels(r, threshold)
    assert labels["x"] == labels["same"] == labels["opposite"]
    assert len(set(labels.values())) == 4
    assert gate.clusters(r, threshold) == 4


@pytest.mark.parametrize("mean_block", [1, 6, 168])
def test_stationary_bootstrap_geometric_blocks(mean_block) -> None:
    """With n=997, P(next=(current+1) mod n)=1-1/L+1/(997L).

    The extra term accounts for a restart that happens to choose the successor.
    Fresh restart decisions make these indicators Bernoulli; the central
    binomial interval has tail probability <=2e-6, not an arbitrary tolerance.
    """
    n, length = 997, 60000
    indices = markets.block_indices(np.random.default_rng(701), length, n, mean_block)
    assert indices.shape == (length,)
    assert np.all((indices >= 0) & (indices < n))
    count = np.count_nonzero(indices[1:] == (indices[:-1] + 1) % n)
    p = 1 - 1 / mean_block + 1 / (mean_block * n)
    low, high = binom.ppf([1e-6, 1 - 1e-6], length - 1, p)
    assert low <= count <= high


def test_stationary_bootstrap_single_source_and_zero_draws() -> None:
    """The only index in a one-row source is 0, even across restarts/wraps."""
    np.testing.assert_array_equal(markets.block_indices(np.random.default_rng(3), 20, 1, 6), np.zeros(20))
    assert markets.block_indices(np.random.default_rng(3), 0, 20, 6).size == 0


def test_funding_bootstrap_joint_rows_and_168_hours(monkeypatch: pytest.MonkeyPatch) -> None:
    """NULLS common pieces: funding and premium, across coins, share block starts."""
    f = np.arange(2400).reshape(200, 12) / 1e6
    premium = 2 * f + 0.01
    spec = {"arrays": (f, premium), "coins": [f"C{i}" for i in range(12)], "block_hours": 168}
    calls = []
    actual = markets.block_indices

    def indices(rng, n, length, mean_block):
        calls.append(mean_block)
        return actual(rng, n, length, mean_block)

    monkeypatch.setattr(markets, "block_indices", indices)
    funding, prem = markets.funding_paths(np.random.default_rng(90), spec, 12, 1000)
    assert calls and set(calls) == {168}
    np.testing.assert_allclose(prem, 2 * funding + 0.01, atol=1e-15)
    np.testing.assert_allclose(funding - funding[:, :1], np.tile(np.arange(12) / 1e6, (1000, 1)), atol=1e-15)


@pytest.mark.parametrize(
    "r, expected",
    [
        ([], Fraction(1)),
        ([100.0], Fraction(1)),
        ([-1.0], Fraction(1)),
        ([0.0, 0.0, 1.0], Fraction(1)),
        ([1.0, 1.0], Fraction(2, 3)),
        ([1.0, 1.0, -1.0], Fraction(2, 3)),
        ([1.0, -1.0, 1.0], Fraction(1)),
        ([-1.0, 1.0, 1.0], Fraction(1)),
        ([4.0, 1.0, 1.0], Fraction(34, 55)),
        ([1.0, 1.0, -1.0, 1.0], Fraction(2, 3)),
    ],
)
def test_betting_hand_wealth(r, expected) -> None:
    """λ1=0. For [4,1,1], λ2=1/4, λ3=5/17: Kmax=(5/4)(22/17).

    [1,1,-1] peaks at 3/2 before losing: use maximum, not terminal wealth.
    [1,-1,1] has λ3=0; [0,0,1] has Q=0 until the final observation.
    [-1,1,1] tests clipping negative/zero past sums to zero.
    """
    assert gate.holdout_pvalue(r) == pytest.approx(float(expected), abs=2e-15)


def test_betting_vectorization_zeros_and_no_retired_activity_floor() -> None:
    """A one-step positive return cannot bet on itself, however large it is.
    Once learned, ten unit returns have p=(2/3)^9; 99% flat steps do not retire
    the test (the old activity floor is explicitly withdrawn in calibration v3).
    """
    rows = np.zeros((2, 1000))
    rows[0, -10:] = 1
    rows[1, -1] = 1e10
    np.testing.assert_allclose(gate.holdout_pvalues(rows), [(2 / 3) ** 9, 1], rtol=2e-14)
    np.testing.assert_array_equal(gate.holdout_pvalues(np.empty((3, 0))), np.ones(3))
    assert gate.holdout_pvalues(np.empty((0, 3))).shape == (0,)


@pytest.mark.parametrize("bad", [np.nextafter(-1.0, -np.inf), -2.0, np.nan, np.inf, -np.inf])
def test_betting_loss_bound_and_nonfinite_are_failures(bad) -> None:
    """Every return, including the first with λ=0, must be finite and >=-B=-1."""
    with pytest.raises(ValueError):
        gate.holdout_pvalue([bad])
    with pytest.raises(ValueError):
        gate.holdout_pvalues([[1.0, 1.0], [0.0, bad]])


@pytest.mark.xfail(
    strict=True,
    reason="Paper §8 permits all finite returns >=-1 and requires λ=S/Q; overflowing Q makes [1e200,1e200] return p=1 instead of 1/2, and larger finite sums raise",
)
@pytest.mark.parametrize("value, n", [(1e200, 2), (1e308, 3)])
def test_betting_large_finite_constant_returns(value, n) -> None:
    """For n identical A>=2, λ_t=1/A for t>=2; Kmax=2^(n-1).
    No mathematical wealth overflows here: Kmax is only 2 or 4.
    Neither 1e200 nor 1e308 is a campaign-producible per-bar return.
    """
    with np.errstate(over="ignore", invalid="ignore"):
        assert gate.holdout_pvalue([value] * n) == pytest.approx(2.0 ** (1 - n))


@pytest.mark.xfail(
    strict=True,
    reason="Paper §8 requires λ2=min(1/2,r1/r1²); Q underflows for r1=1e-300, so holdout_pvalue returns 1 instead of approximately 2e-300",
)
def test_betting_small_finite_history_does_not_become_zero_history() -> None:
    """r1=1e-300 implies λ2=1/2, not zero; r2=1e300 gives K=1+5e299.
    This pair is not campaign-producible: equity-change returns cannot resolve
    a nonzero 1e-300 relative change, and 1e300 is outside the market-return range.
    """
    with np.errstate(over="ignore", under="ignore", invalid="ignore"):
        assert gate.holdout_pvalue([1e-300, 1e300]) == pytest.approx(1 / (1 + 0.5e300), rel=2e-14, abs=0)


def test_betting_all_bounded_coin_paths_are_superuniform() -> None:
    """Exact enumeration, not Monte Carlo: 2^12 equiprobable fair ±1 paths.

    E[r|past]=0 and r>=-1, so Ville gives #{p<=u} <= 4096*u at every
    attainable threshold (including all ties), not only alpha=.05.
    """
    paths = np.array(list(itertools.product([-1.0, 1.0], repeat=12)))
    p = gate.holdout_pvalues(paths)
    values, counts = np.unique(p, return_counts=True)
    assert np.all(np.cumsum(counts) <= len(paths) * values + 1e-10)


@pytest.mark.parametrize("null", ["fair", "predictable_scale", "rare_loss"])
def test_betting_seeded_null_calibration(null) -> None:
    """4096 paths of length 128; every generator is a conditional-mean-zero null.

    Fair: ±1. Predictable scale: ±(.1 or 1), scale set by the previous sign.
    Rare loss: -1 with probability .1, +1/9 otherwise, giving mean zero.
    For u=.05,.01,.005 reject counts must not exceed Bin(4096,u)'s
    (1-1e-6) quantile. Stochastic domination follows directly from Ville;
    the union failure probability across these nine checks is <=9e-6.
    """
    rng = np.random.default_rng(90210)
    draws = rng.random((4096, 128))
    if null == "rare_loss":
        r = np.where(draws < 0.1, -1.0, 1 / 9)
    else:
        r = np.where(draws < 0.5, -1.0, 1.0)
        if null == "predictable_scale":
            scales = np.ones_like(r)
            scales[:, 1:] = np.where(r[:, :-1] > 0, 1.0, 0.1)
            r *= scales
    p = gate.holdout_pvalues(r)
    assert np.all(np.isfinite(p) & (p > 0) & (p <= 1))
    for u in [0.05, 0.01, 0.005]:
        assert np.count_nonzero(p <= u) <= binom.ppf(1 - 1e-6, len(p), u)


@pytest.mark.parametrize(
    "p, adjusted",
    [
        ([], []),
        ([0.02], [0.02]),
        ([0.0, 1.0], [0.0, 1.0]),
        ([0.04, 0.01, 0.03], [0.06, 0.03, 0.06]),
        ([0.01, 0.01, 0.03], [0.03, 0.03, 0.03]),
        ([0.9, 0.8, 0.7], [1.0, 1.0, 1.0]),
        ([0.05 / 3, 0.025, 0.05], [0.05, 0.05, 0.05]),
    ],
)
def test_holm_hand_adjustments_and_permutations(p, adjusted) -> None:
    """Holm: sorted q_j=min(1,max_{k<=j}(m-k+1)p_(k)); undo sorting.
    Enumerating permutations checks original order and exchangeable ties.
    """
    for order in itertools.permutations(range(len(p))):
        np.testing.assert_allclose(gate.holm(np.array(p)[list(order)]), np.array(adjusted)[list(order)], atol=1e-15)


def test_promotion_needs_positive_return_and_keeps_entire_family() -> None:
    """Ten unit returns give p=(2/3)^9=.0260123. Alone this passes .05;
    an absent finalist (p=1,R=0) must keep m=2, so .0520246 fails.
    An early wealth peak does not excuse negative compounded net return.
    """
    r = np.ones(10)
    assert gate.promote({"a": (r, 1.0, None)})[0] == ["a"]
    assert gate.promote({"a": (r, 1.0, None), "missing": (np.array([]), 0.0, None)})[0] == []
    for total in [0.0, -np.finfo(float).eps, -1.0]:
        assert gate.promote({"a": (r, total, None)})[0] == []
    assert gate.promote({"a": (r, np.finfo(float).tiny, None)})[0] == ["a"]
    assert gate.promote({})[0] == []
    peak_then_bankrupt = np.r_[np.ones(12), -1.0]
    assert gate.holdout_pvalue(peak_then_bankrupt) < 0.05
    assert gate.promote({"a": (peak_then_bankrupt, -1.0, None)})[0] == []


def test_promotion_holm_threshold_is_inclusive(monkeypatch: pytest.MonkeyPatch) -> None:
    """Two p=.025 ties both adjust to .05: preset level 'passes' includes equality."""
    monkeypatch.setattr(gate, "holdout_pvalue", lambda r: 0.025)
    results = {"b": ([1.0], 1.0, None), "a": ([1.0], 1.0, None)}
    assert set(gate.promote(results)[0]) == {"a", "b"}


def test_betting_and_holm_have_no_retired_pvalue_floor() -> None:
    """Calibration v3 retires the .0015 floor and 33-finalist limit.
    Fifty unit returns give p=(2/3)^49; even Holm times 100 is below .05.
    """
    results = {str(i): (np.ones(50), 1.0, None) for i in range(100)}
    promoted, report = gate.promote(results)
    assert set(promoted) == set(results)
    assert report["holm"]["0"] == pytest.approx(100 * (2 / 3) ** 49, rel=2e-13)


class SyntheticProcess:
    """Only the CLI transport is replaced; the real daemon enforces its budget."""

    def __init__(self, response) -> None:
        self.stdin = io.StringIO()
        self.stdout = io.StringIO((json.dumps(response) + "\n") * 110)

    def terminate(self) -> None:
        pass

    def wait(self, *args, **kwargs) -> int:
        return 0

    def poll(self) -> None:
        return None


@pytest.mark.parametrize(
    "response",
    [
        {"ok": False, "code": "TYPE", "message": "synthetic rejection"},
        {"ok": True, "summary": {"fills": 0, "sharpe_annualized": 0.0, "total_return": 0.0, "max_drawdown": 0.0}},
    ],
)
def test_budget_duplicates_rejections_zero_fills_and_free_checks(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, response
) -> None:
    """Stage 3/4: each arm has 100 evaluations; checks free, every eval counts.
    Four agents therefore permit exactly 400 calls, not 400 distinct strategies.
    A budget refusal never reaches the evaluator and cannot become an evaluation.
    """
    processes = []

    def popen(*args, **kwargs):
        process = SyntheticProcess(response)
        processes.append(process)
        return process

    monkeypatch.setattr(daemon, "command", lambda *args, **kwargs: ["synthetic-mm"])
    monkeypatch.setattr(daemon.subprocess, "Popen", popen)
    monkeypatch.setattr(daemon.subprocess, "run", lambda *a, **k: SimpleNamespace(returncode=0, stdout="{}", stderr=""))
    for agent in "ABCD":
        d = daemon.Daemon(
            tmp_path / f"{agent}.sock", tmp_path, tmp_path / "ledger", "spec", agent, 100, tmp_path / f"{agent}.log"
        )
        d.server = SimpleNamespace(close=lambda: None)
        try:
            for _ in range(101):
                d.check("{}")
            accepted = [d.eval("{}") for _ in range(100)]
            assert all(row.get("code") != "BUDGET" for row in accepted)
            assert d.eval("{}")["code"] == "BUDGET"
            assert d.eval("{}")["code"] == "BUDGET"
            assert len(processes[-1].stdin.getvalue().splitlines()) == 100
        finally:
            d.close()


def test_budget_reservation_is_atomic(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """With one slot and eight concurrent requests exactly one may reach the CLI."""
    process = SyntheticProcess({"ok": False, "code": "TYPE"})
    monkeypatch.setattr(daemon, "command", lambda *a, **k: ["synthetic-mm"])
    monkeypatch.setattr(daemon.subprocess, "Popen", lambda *a, **k: process)
    d = daemon.Daemon(tmp_path / "s", tmp_path, tmp_path / "l", "spec", "A", 1, tmp_path / "log")
    d.server = SimpleNamespace(close=lambda: None)
    try:
        with ThreadPoolExecutor(max_workers=8) as pool:
            replies = list(pool.map(lambda _: d.eval("{}"), range(8)))
        assert sum(row.get("code") == "BUDGET" for row in replies) == 7
        assert len(process.stdin.getvalue().splitlines()) == 1
    finally:
        d.close()


def synthetic_params():
    return {
        "funding": None,
        "lambda": 0.5,
        "garch": {"omega": [0.00004] * 12, "alpha": [0.1] * 12, "beta": [0.8] * 12},
        "regime": {
            "P": [[0.9, 0.1], [0.2, 0.8]],
            "m": [1.0, 1.0],
            "rho": [0.36, 0.36],
            "sigma": [0.02] * 12,
            "p_jump": 0.0,
            "k_jump": 0.01,
        },
    }


def truncated_t_fourth():
    """t5|(|t5|<=8): E[t^4]=25 I_z(5/2,1/2)/I_z(1/2,5/2)."""
    z = 64 / 69
    variance = (5 / 3) * betainc(1.5, 1.5, z) / betainc(0.5, 2.5, z)
    fourth = 25 * betainc(2.5, 0.5, z) / betainc(0.5, 2.5, z)
    return fourth / variance**2


@pytest.mark.parametrize("nu, bound", [(5, 8.0), (5, 1.0), (4, 8.0)])
def test_truncated_student_exact_second_moment(nu, bound) -> None:
    """Integrating the t density gives conditional E[X²]=nu/(nu-2)
    * I_z(3/2,(nu-2)/2)/I_z(1/2,nu/2), z=b²/(nu+b²).
    This is a truncated, not winsorized, t and not the untruncated sd.
    """
    z = bound**2 / (nu + bound**2)
    variance = nu / (nu - 2) * betainc(1.5, (nu - 2) / 2, z) / betainc(0.5, nu / 2, z)
    assert markets.truncated_t_sd(nu, bound) ** 2 == pytest.approx(variance, rel=2e-12)


def test_truncated_innovations_have_unit_variance_and_symmetric_mean() -> None:
    """NULLS N2/N3: t5 conditional on |t|<=8, standardized to variance 1.
    Bounded fourth moment <=(8/sd)^2 gives a conservative six-SE variance band.
    """
    n = 80000
    sd = markets.truncated_t_sd(5, 8.0)
    x = markets.truncated_t(np.random.default_rng(221), 5, (n,))
    assert np.max(np.abs(x)) <= 8 / sd
    assert abs(x.mean()) <= 6 / math.sqrt(n)
    assert abs(np.mean(x**2) - 1) <= 6 * math.sqrt(((8 / sd) ** 2 - 1) / n)


@pytest.mark.parametrize("model", ["N1", "N2", "N3"])
def test_null_conditional_accounting_and_symmetric_moments(model) -> None:
    """NULLS: c/o=(1+f1+f2+f3+eps)/(1-f4), hence gross PnL/(q*o)=eps.
    Conditional on the predictable sigma, E[eps]=0. Here volatility is low
    enough that the bounded innovations never hit the symmetric clipping cap.
    For x=a*z_m+b*z_i, a²+b²=1, E[x^4]=(a^4+b^4)kappa+6a²b².
    E[x_i²*x_j²]=1+a^4(kappa-1). These give the six-SE second-moment
    and cross-moment bands below. No kernel or data run is involved.
    """
    a = markets.generate(model, synthetic_params(), f"spec-moments-{model}", 700)
    o, close, eps, sigma = (a[k] for k in ["open", "close", "eps", "sigma"])
    assert eps.shape == (4200, 12)
    funding = a["funding"]
    bar_funding = funding[1:].reshape(4200, 4, 12)
    gross = close / o - 1 - bar_funding[:, :3].sum(axis=1) - (close / o) * bar_funding[:, 3]
    np.testing.assert_allclose(gross, eps, atol=5e-16)
    np.testing.assert_array_equal(o[1:], close[:-1])
    assert np.all(close > 0)
    assert np.max(np.abs(eps)) <= 0.5
    x = eps / sigma
    rho = {"N1": 0.0, "N2": 0.25, "N3": 0.36}[model]
    kappa = 3.0 if model == "N1" else truncated_t_fourth()
    fourth = (rho**2 + (1 - rho) ** 2) * kappa + 6 * rho * (1 - rho)
    second_tolerance = 6 * math.sqrt((fourth - 1) / len(x))
    for column in x.T:
        assert abs(column.mean()) < 6 / math.sqrt(len(column))
        assert abs(np.mean(column**2) - 1) < second_tolerance
    if model == "N1":
        np.testing.assert_array_equal(sigma, np.full_like(sigma, 0.02))
        np.testing.assert_array_equal(funding, np.zeros_like(funding))
        np.testing.assert_array_equal(a["premium"], np.zeros_like(a["premium"]))
    if model == "N2":
        expected = np.minimum(0.00004 + 0.1 * eps[:-1] ** 2 + 0.8 * sigma[:-1] ** 2, 0.0625**2)
        np.testing.assert_allclose(sigma[0] ** 2, 0.0004, rtol=1e-13)
        np.testing.assert_allclose(sigma[1:] ** 2, expected, rtol=1e-13)
    cross_tolerance = 6 * math.sqrt((1 + rho**2 * (kappa - 2)) / len(x))
    assert abs(np.mean(x[:, 0] * x[:, 1]) - rho) < cross_tolerance


def test_n2_variance_cap_is_recursive_state() -> None:
    """The cap applies to the state, including initial omega/(1-alpha-beta)."""
    params = synthetic_params()
    params["garch"] = {"omega": [0.01] * 12, "alpha": [0.1] * 12, "beta": [0.8] * 12}
    a = markets.generate("N2", params, "spec-cap", 3)
    np.testing.assert_array_equal(a["sigma"], np.full_like(a["sigma"], 0.0625))


@pytest.mark.xfail(
    strict=True, reason="NULLS.md N3 requires Laplace jumps truncated at ±0.2; generate clips them, inflating E[K²]"
)
def test_n3_truncated_laplace_jump_moment() -> None:
    """For |K|<=a truncated Laplace(0,k), E[K²]=
    2k²[1-exp(-a/k)(1+a/k+(a/k)²/2)]/[1-exp(-a/k)].
    Tiny diffusion prevents epsilon clipping, so Var(eps)=sigma²+p_j E[K²].
    k=.1 makes clipping versus rejection distinguishable at the stated bound.
    This stress scale amplifies a real-path defect: at every k_j>0 and p_j>0,
    a Laplace proposal exceeds the bound with probability p_j*exp(-.2/k_j).
    Changing a jump changes gross strategy PnL by q*o*Δeps (NULLS accounting).
    """
    params = synthetic_params()
    params["regime"].update(sigma=[0.001] * 12, p_jump=0.2, k_jump=0.1)
    a = markets.generate("N3", params, "spec-laplace", 1000)
    eps = a["eps"].ravel()
    k, cutoff = 0.1, 0.2
    z = cutoff / k
    second = 2 * k * k * (1 - math.exp(-z) * (1 + z + z * z / 2)) / (1 - math.exp(-z))
    variance = 0.001**2 + 0.2 * second
    assert abs(eps.mean()) <= 6 * math.sqrt(variance / len(eps))
    assert np.mean(eps**2) == pytest.approx(variance, rel=0.07)


@pytest.mark.xfail(
    strict=True,
    reason="NULLS.md N3 requires truncation: reject K=0.3 and redraw 0.1; generate instead emits the clipped jump 0.2",
)
def test_n3_jump_rejects_outside_truncation_interval(monkeypatch: pytest.MonkeyPatch) -> None:
    """Deterministic counterexample: Laplace proposals .3, then .1 forever.

    Conditional sampling rejects .3, accepts .1. Coupling a zero-jump run
    removes the same Student diffusion; the first jump must therefore be .1.
    Both runs have p_j=.02 and k_j=.01, not an always-jumping stress market;
    the RNG replacement changes only Laplace proposals. The tail event is rare
    but has positive probability at this scale, unlike the extreme betting inputs.
    """
    factory = np.random.default_rng

    class RNG:
        def __init__(self, seed, jump) -> None:
            self.rng = factory(seed)
            self.jump = jump
            self.calls = 0

        def __getattr__(self, name):
            return getattr(self.rng, name)

        def laplace(self, loc: float = 0.0, scale: float = 1.0, size=None):
            self.calls += 1
            value = (0.3 if self.calls == 1 else 0.1) if self.jump else 0.0
            return np.full(size, value)

    params = synthetic_params()
    params["regime"].update(sigma=[0.001] * 12, p_jump=0.02, k_jump=0.01)
    monkeypatch.setattr(markets.np.random, "default_rng", lambda seed: RNG(seed, False))
    baseline = markets.generate("N3", params, "spec-truncation-0", 1)
    monkeypatch.setattr(markets.np.random, "default_rng", lambda seed: RNG(seed, True))
    jumped = markets.generate("N3", params, "spec-truncation-0", 1)
    delta = jumped["eps"][0] - baseline["eps"][0]
    assert np.any(delta)
    np.testing.assert_allclose(delta[delta != 0], 0.1, atol=1e-15)


def test_n1_wicks_and_lognormal_volume_moments() -> None:
    """|N(0,(sigma/2)²)| has mean sigma/sqrt(2pi), second moment sigma²/4.
    NULLS volume has log mean 10, log variance .25. Tolerances are six SE.
    """
    a = markets.generate("N1", {}, "spec-wicks-volume", 500)
    log_volume = np.log(a["volume"])
    n = log_volume.size
    assert abs(log_volume.mean() - 10) <= 6 * 0.5 / math.sqrt(n)
    assert abs(np.mean((log_volume - 10) ** 2) - 0.25) <= 6 * 0.25 * math.sqrt(2 / n)
    upper = a["high"] / np.maximum(a["open"], a["close"]) - 1
    lower = 1 - a["low"] / np.minimum(a["open"], a["close"])
    for wick in [upper, lower]:
        assert np.all(wick >= 0)
        assert abs(wick.mean() - 0.01 * math.sqrt(2 / math.pi)) <= 6 * 0.01 / math.sqrt(n)
        assert abs(np.mean(wick**2) - 0.0001) <= 6 * 0.0001 * math.sqrt(2 / n)
        assert abs(np.mean((wick - wick.mean()) * a["eps"])) <= 6 * 0.01 * 0.02 / math.sqrt(n)


def test_planted_mean_is_predictable_funding_signal() -> None:
    """In N1, settled funding=0: g=-clip((0-1.25e-5)/1e-4)=1/8.
    beta=.1 therefore adds exactly .0125 after the first bar on planted coins.
    N1's |sigma*x|<=.16 makes clipping impossible here. Same seed couples noise.
    The initial bar's prior boundary is unspecified and is deliberately excluded.
    """
    null = markets.generate("N1", {}, "spec-plant-pair", 20)
    planted = markets.generate("N1", {}, "spec-plant-pair", 20, planted=[0, 3], beta=0.1)
    expected = np.zeros((119, 12))
    expected[:, [0, 3]] = 0.0125
    np.testing.assert_allclose(planted["eps"][1:] - null["eps"][1:], expected, atol=2e-17)


def test_planted_signal_uses_previous_boundary_and_both_clip_limits() -> None:
    """Use a synthetic nonconstant funding tape, fixed sigma and coupled draws.
    No epsilon clipping occurs: Δeps=beta*g, where g uses f_(b-4h),
    subtracts the interest floor and clips the normalized signal to ±1.
    Alpha=beta_GARCH=0 prevents a planted shock from changing future sigma.
    """
    params = synthetic_params()
    params["garch"] = {"omega": [1e-8] * 12, "alpha": [0.0] * 12, "beta": [0.0] * 12}
    funding = 1.25e-5 + np.resize(np.array([-2e-4, -5e-5, 0.0, 5e-5, 2e-4]), (500, 12))
    params["funding"] = {
        "arrays": (funding, np.zeros_like(funding)),
        "coins": [f"C{i}" for i in range(12)],
        "block_hours": 168,
    }
    null = markets.generate("N2", params, "spec-plant-lag", 40)
    planted = markets.generate("N2", params, "spec-plant-lag", 40, planted=[0, 3], beta=0.01)
    previous_funding = null["funding"][np.arange(239) * 4]
    g = -np.clip((previous_funding - 1.25e-5) / 1e-4, -1, 1)
    expected = np.zeros((239, 12))
    expected[:, [0, 3]] = 0.01 * g[:, [0, 3]]
    assert set(np.unique(g)) >= {-1.0, 0.0, 1.0}
    np.testing.assert_allclose(planted["eps"][1:] - null["eps"][1:], expected, atol=2e-17)


@pytest.mark.parametrize("beta, limit", [(8.0, 0.5), (-8.0, -0.5)])
def test_planted_epsilon_saturates_at_stated_bound(beta, limit) -> None:
    """N1 g=1/8; beta=±8 makes the whole support exceed ±.5 before clipping."""
    a = markets.generate("N1", {}, "spec-plant-saturate", 2, planted=[0], beta=beta)
    np.testing.assert_array_equal(a["eps"][1:, 0], np.full(11, limit))


def evidence(evaluations: int = 0, received: bool = False, holds: bool = True, crash: bool = False):
    return {
        "evaluations": evaluations,
        "received": received,
        "holds": holds,
        "run": {"stopped": "finished", "exit": 1 if crash else 0},
    }


@pytest.mark.parametrize(
    "change, expected",
    [
        ({}, "established"),
        ({"promoted": True, "crash": True, "agents": []}, "promoted"),
        ({"crash": True}, "unresolved"),
        ({"agents": []}, "unresolved"),
        ({"trials": 0}, "not established"),
        ({"history": False}, "not established"),
        ({"agents": [evidence(1, True), evidence(), evidence(), evidence()]}, "not established"),
        ({"agents": [evidence(1, True), evidence(1, True), evidence(crash=True), evidence()]}, "established"),
        (
            {"agents": [evidence(1, True), evidence(1, True), evidence(received=True, crash=True), evidence()]},
            "unresolved",
        ),
        ({"agents": [evidence(1, True), evidence(1, True), evidence(holds=False), evidence()]}, "unresolved"),
    ],
)
def test_c45_v3_classes(change, expected) -> None:
    """Latest revision: promotions dominate; silence is not a failed procedure.
    Two evaluating agents, one filled trial and cross-agent history suffice;
    a crash after any disclosure or missing evidence instead makes unresolved.
    """
    args = dict(
        promoted=False,
        crash=False,
        agents=[evidence(1, True), evidence(1, True), evidence(), evidence()],
        trials=1,
        history=True,
    )
    args.update(change)
    assert campaigns.swarm_class(**args) == expected


@pytest.mark.parametrize(
    "classes, expected",
    [
        ([], "not established"),
        (["established"] * 9, "not established"),
        (["established"] * 10, "pass"),
        (["established"] * 9 + ["promoted"], "pass"),
        (["established"] * 9 + ["unresolved"], "pass"),
        (["established"] * 9 + ["not established"], "pass"),
        (["established"] * 8 + ["not established"] * 2, "not established"),
        (["promoted", "unresolved"], "failed"),
        (["promoted"] * 2 + ["established"] * 8, "failed"),
        (["unresolved"] * 2 + ["established"] * 8, "failed"),
    ],
)
def test_c45_v3_verdict_arithmetic(classes, expected) -> None:
    """Failure at P+U>=2 dominates even an incomplete series; pass needs ten.
    Neither an incomplete series nor two residual classes is a free retry/pass.
    """
    for order in [classes, list(reversed(classes))]:
        assert campaigns.swarm_verdict(order) == expected
