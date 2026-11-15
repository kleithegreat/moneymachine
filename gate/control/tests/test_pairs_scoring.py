"""Study 1, step 1: a pair written for scoring (behaviour 5) and law L1.5 (audit/program/briefs/1-positive-control.md,
revised 2026-11-13 at 2aec11c). Written from the plan before the code, by a model other than the builder's, as L1.5
requires.

"The market" here is built from the frozen generator and `gate.markets.write` (`support.study_market`), never by the
code under test, so a fault shared by `write_pair` and `pairs.write_market` cannot hide.

Interface, as the plan and the built tests fix it: `pairs.write_pair(root, market_id, strength) -> (planted path, twin
path)`, the twin at strength 0."""

import json
import random
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import polars as pl
import pytest
from hypothesis import HealthCheck, example, given, settings
from hypothesis import strategies as st
from polars.testing import assert_frame_equal

from gate import search
from gate.control import pairs
from gate.control.tests import support
from gate.kernel import command

pytestmark = pytest.mark.usefixtures("built_kernel")

Program = dict[str, Any]

PROGRAMS = Path(__file__).resolve().parents[1] / "programs"
LOCKED = sorted(PROGRAMS.glob("*.json"))
REJECTED: Program = support.program({"op": "sign", "args": [{"input": "forum_posts"}]}, "rejected")
UNREAD = ("hash", "source")
G100_PROGRAMS = 5
ABSENT = "absent"

strengths = st.one_of(st.just(0.0), st.just(0.01), st.floats(min_value=0.0, max_value=0.01, allow_nan=False))
base_ids = st.one_of(
    st.integers(0, 99).map(lambda i: f"control-1-m{i:03d}"),
    st.integers(0, 1599).map(lambda i: f"control-1-cal-a-{i:04d}"),
    st.integers(0, 9999).map(lambda i: f"control-1-cal-b-{i:04d}"),
    st.integers(0, 199).map(lambda i: f"control-1-blind-{i:03d}"),
)
market_ids = st.one_of(
    st.tuples(base_ids, st.integers(0, 56)).map(lambda pair: f"{pair[0]}/fresh/{pair[1]}"),
    base_ids,
)


def g100_programs(seed: int, market: Path) -> list[Program]:
    """Programs as G100 makes them: random genomes, a mutation and a crossover, compiled."""
    rng = random.Random(seed)
    count = search.features(market)
    genomes = [search.random_genome(rng, count) for _ in range(G100_PROGRAMS - 2)]
    genomes.append(search.mutate(rng, genomes[0], count))
    genomes.append(search.crossover(rng, genomes[1], genomes[2]))
    return [search.compile_genome(genome) for genome in genomes]


def disclosed(programs: list[str], market: Path, ledger: Path) -> list[object]:
    """The `sharpe_annualized` that one `mm eval -` process discloses for each program on `market`, as the text the
    kernel printed (so equal means bit for bit), None for a JSON null, or ABSENT when the line carries no such
    statistic."""
    process = subprocess.run(
        command("eval", "-", "scratch", "scratch", ledger, market, "--disclose", "sharpe_annualized"),
        input="".join(text + "\n" for text in programs),
        capture_output=True,
        text=True,
        check=False,
    )
    lines = process.stdout.splitlines()
    assert len(lines) == len(programs), process.stderr
    found: list[object] = []
    for line in lines:
        parsed = json.loads(line, parse_float=str, parse_constant=str, parse_int=str)
        statistics = parsed.get("disclosure", {}).get("result", {})
        found.append(statistics.get("sharpe_annualized", ABSENT))
    return found


@settings(max_examples=20, deadline=None, suppress_health_check=[HealthCheck.too_slow])
@example(market_id="control-1-m000/fresh/0", strength=0.0, seed=0)
@example(market_id="control-1-cal-a-0007/fresh/56", strength=0.01, seed=1)
@given(market_ids, strengths, st.integers(0, 2**32 - 1))
def test_l1_5_a_pair_written_for_scoring_scores_bit_for_bit_as_the_market(
    market_id: str, strength: float, seed: int
) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        planted, twin = (Path(path) for path in pairs.write_pair(root / "pair", market_id, strength))
        full_planted = support.study_market(root / "full-planted", market_id, strength)
        full_twin = full_planted if strength == 0.0 else support.study_market(root / "full-twin", market_id, 0.0)
        programs = [json.dumps(json.loads(path.read_text()), sort_keys=True) for path in LOCKED]
        programs += [json.dumps(program, sort_keys=True) for program in g100_programs(seed, full_planted)]
        programs.append(json.dumps(REJECTED, sort_keys=True))
        programs = list(dict.fromkeys(programs))
        for name, written, market in (("planted", planted, full_planted), ("twin", twin, full_twin)):
            got = disclosed(programs, written, root / f"{name}-pair.sqlite")
            want = disclosed(programs, market, root / f"{name}-full.sqlite")
            assert got == want, name
            assert ABSENT not in got[: len(LOCKED)]
            assert got[-1] == ABSENT


def parquet_files(market: Path) -> list[Path]:
    return sorted(path.relative_to(market) for path in (market / "store").rglob("*.parquet"))


@pytest.mark.parametrize("strength", [0.005, 0.0])
def test_a_pair_holds_the_stores_rows_without_hash_source_or_holdout(tmp_path: Path, strength: float) -> None:
    market_id = "control-1-m002/fresh/9"
    planted, twin = (Path(path) for path in pairs.write_pair(tmp_path / "pair", market_id, strength))
    for written, beta in ((planted, strength), (twin, 0.0)):
        full = support.study_market(tmp_path / f"full-{written.name}-{beta}", market_id, beta)
        assert not (written / "holdout").exists()
        assert parquet_files(written) == parquet_files(full)
        for relative in parquet_files(full):
            got = pl.read_parquet(written / relative)
            want = pl.read_parquet(full / relative).drop(*UNREAD)
            assert not set(UNREAD) & set(got.columns), relative
            assert "fetchedAt" in got.columns, relative
            assert_frame_equal(got, want, check_column_order=False)
        for name in ("store/policy.json", "venue/rules.json", "venue/execution.json"):
            assert json.loads((written / name).read_text()) == json.loads((full / name).read_text()), name
        assert (written / "version").read_text() == (full / "version").read_text()
