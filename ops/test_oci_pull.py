import subprocess
from datetime import date, timedelta
from pathlib import Path

FILTER = Path(__file__).parent / "oci/forward-window.exclude"


def test_forward_window_days_are_not_pulled(tmp_path):
    src, dst = tmp_path / "src", tmp_path / "dst"
    src.mkdir()
    dst.mkdir()
    days = [date(2026, 10, 20) + timedelta(d) for d in range(0, 120)]
    for d in days:
        (src / f"polls-{d:%Y%m%d}.jsonl").touch()
    (src / "recorder.json").touch()
    subprocess.run(["rsync", "-a", f"--exclude-from={FILTER}", f"{src}/", f"{dst}/"], check=True)
    pulled = {p.name for p in dst.iterdir()}
    for d in days:
        inside = date(2026, 11, 1) <= d < date(2027, 1, 31)
        assert (f"polls-{d:%Y%m%d}.jsonl" in pulled) != inside, d
    assert "recorder.json" in pulled
